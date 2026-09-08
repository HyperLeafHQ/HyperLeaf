// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract LeafYieldFee {
    using SafeERC20 for IERC20;

    uint16 public constant YIELD_FEE_BPS = 100;
    uint16 public constant BPS_DENOMINATOR = 10_000;

    address public feeRecipient;
    uint256 public lastAccounted;

    bool public convertYieldToHype;
    address public harvester;
    /// @dev pullYield destination. Harvester cannot redirect surplus to self.
    address public converter;
    /// @dev e.g. xSQUID `claimRewards(address,uint256)` = 0x9a99b4f0. Forced args: (this, max).
    bytes4 public rewardsSelector;

    /// @dev Rate-bearing inner (cbETH `exchangeRate`, 4626 `convertToAssets(1e18)`,
    ///      BENQI sAVAX `getPooledAvaxByShares(1e18)`). Surplus is taken from
    ///      `lastAccounted` only — donations are not yield.
    ///      Floor: (lastAccounted * (rate - lastRate)) / rate. Dust stays principal.
    enum RateKind {
        None,
        ExchangeRate,
        ConvertToAssets,
        GetPooledAvaxByShares
    }

    RateKind public rateKind;
    uint256 public lastRate;
    /// @dev Identified rate yield, not yet pulled. Not principal. Not a donation.
    uint256 public accruedRateYield;
    /// @dev true = wstETH-style: 99% of rate surplus stays in the box (NAV in inner).
    ///      Only 1% is pulled to the converter (protocol fee → HYPE).
    ///      false = sell the whole surplus to WHYPE and split 99/1 at notify.
    bool public retainRateYield;

    event ConvertModeSet(bool enabled);
    event HarvesterSet(address indexed harvester);
    event ConverterSet(address indexed converter);
    event RewardsSelectorSet(bytes4 selector);
    event RateFeedSet(RateKind kind, uint256 rate);
    event RateYieldAccrued(uint256 added, uint256 accrued, uint256 rate);
    event RateYieldPulled(address indexed to, uint256 surplus, uint256 rate);
    event RetainRateYieldSet(bool retain);
    event YieldPulled(address indexed token, address indexed to, uint256 amount);
    event FeeRecipientUpdated(address indexed recipient);
    event YieldHarvested(address indexed token, uint256 yieldAmount, uint256 fee);

    error NotHarvester();
    error NoYield();
    error BadConverter();
    error ClaimFailed();
    error ForbiddenRewardsSelector();
    error BadRateFeed();
    error FeeRecipientZero();
    error ConvertHalted();

    function _initFee(address recipient) internal {
        if (recipient == address(0)) revert FeeRecipientZero();
        feeRecipient = recipient;
    }

    function _setFeeRecipient(address recipient) internal {
        if (recipient == address(0)) revert FeeRecipientZero();
        feeRecipient = recipient;
        emit FeeRecipientUpdated(recipient);
    }

    function _accountDeposit(uint256 got) internal {
        lastAccounted += got;
    }

    function _syncAccounted(IERC20 token, uint256 reserved) internal {
        uint256 bal = token.balanceOf(address(this));
        lastAccounted = bal > reserved ? bal - reserved : 0;
    }

    function _setConvertYieldToHype(bool enabled) internal {
        convertYieldToHype = enabled;
        emit ConvertModeSet(enabled);
    }

    function _setHarvester(address harvester_) internal {
        harvester = harvester_;
        emit HarvesterSet(harvester_);
    }

    function _setConverter(address converter_) internal {
        if (converter_ == address(0)) revert BadConverter();
        converter = converter_;
        emit ConverterSet(converter_);
    }

    function _requireConverter(address to) internal view {
        if (converter == address(0) || to != converter) revert BadConverter();
    }

    function _requireConvertOn() internal view {
        if (!convertYieldToHype) revert ConvertHalted();
    }

    /// @notice Only the converter contract. Owner uses `setConvertYieldToHype(false)`.
    function haltConvert() external {
        if (msg.sender != converter) revert BadConverter();
        _setConvertYieldToHype(false);
    }

    function _setRewardsSelector(bytes4 s) internal {
        if (s != bytes4(0) && _forbiddenRewardsSelector(s)) revert ForbiddenRewardsSelector();
        rewardsSelector = s;
        emit RewardsSelectorSet(s);
    }

    /// @dev xSQUID / stkAVNT `claimRewards(address,uint256)` = 0x9a99b4f0.
    ///      Same arity as Squid/Avantis `redeem(address,uint256)` 0x1e9a6950.
    ///      Avantis `claimRewardsAndRedeem` selector is 0xeab52318 (burns stkAVNT).
    ///      Tx 0x24398d72 is that combined redeem *hash*, not a selector — do not
    ///      blacklist the hash prefix.
    function _forbiddenRewardsSelector(bytes4 s) internal pure returns (bool) {
        return s == bytes4(0x1e9a6950) // redeem(address,uint256)
            || s == bytes4(0xeab52318) // claimRewardsAndRedeem(address,uint256,uint256) — Avantis
            || s == bytes4(0x787a08a6) // cooldown()
            || s == bytes4(0xb460af94) // withdraw(uint256,address,address)
            || s == bytes4(0xba087652) // redeem(uint256,address,address)
            || s == bytes4(0x9343d9e1) // cooldownShares(uint256)
            || s == bytes4(0xcdac52ed) // cooldownAssets(uint256)
            || s == bytes4(0x1e83409a) // claim(address)
            || s == bytes4(0x9ad82aa0) // queueRedeem
            || s == bytes4(0x50b3f984) // queueWithdraw
            || s == bytes4(0xc9d2ff9d) // requestUnlock(uint256) — BENQI sAVAX 15d
            || s == bytes4(0x2e1a7d4d) // withdraw(uint256) — BENQI claim AVAX / SOON 90d unlock
            || s == bytes4(0x1338736f) // lock(uint256,uint256) — SOON occupancy 0x6601, not gSOON vault
            || s == bytes4(0x6e553f65) // deposit(uint256,address) — ERC-4626; poke arity matches
            || s == bytes4(0x94bf804d); // mint(uint256,address)
    }

    /// @dev Claims as this lockbox. Selector must be rewards, not redeem — same
    ///      arity as Squid redeem, different 4 bytes (0x9a99b4f0 vs 0x1e9a6950).
    function _pokeRewards(address inner) internal {
        bytes4 s = rewardsSelector;
        if (s == bytes4(0) || inner == address(0)) revert ClaimFailed();
        if (_forbiddenRewardsSelector(s)) revert ForbiddenRewardsSelector();
        (bool ok,) = inner.call{value: msg.value}(abi.encodeWithSelector(s, address(this), type(uint256).max));
        if (!ok) revert ClaimFailed();
    }

    function _harvestInner(IERC20 token, uint256 reserved) internal returns (uint256 fee) {
        if (convertYieldToHype) return 0;
        uint256 bal = token.balanceOf(address(this));
        if (bal <= reserved) {
            lastAccounted = 0;
            return 0;
        }
        uint256 free = bal - reserved;
        if (free <= lastAccounted) return 0;
        uint256 y = free - lastAccounted;
        // 1% of y. y < 100 ⇒ fee 0, dust stays with holders (not the protocol).
        fee = (y * YIELD_FEE_BPS) / BPS_DENOMINATOR;
        if (fee > 0) {
            token.safeTransfer(feeRecipient, fee);
            free -= fee;
        }
        lastAccounted = free;
        emit YieldHarvested(address(token), y, fee);
    }

    /// @dev Inner that backs shares: balance minus reserved minus identified fee/yield.
    ///      Donations sit in here (gift to holders). Accrued protocol take does not.
    function _backingInner(IERC20 token, uint256 reserved) internal view returns (uint256) {
        uint256 bal = token.balanceOf(address(this));
        uint256 free = bal > reserved ? bal - reserved : 0;
        if (accruedRateYield >= free) return 0;
        return free - accruedRateYield;
    }

    function _assetsForShares(IERC20 token, uint256 shares, uint256 totalShares, uint256 reserved)
        internal
        view
        returns (uint256)
    {
        if (shares == 0 || totalShares == 0) return 0;
        uint256 bal = token.balanceOf(address(this));
        uint256 free = bal > reserved ? bal - reserved : 0;
        if (convertYieldToHype && rateKind == RateKind.None) return shares;
        if (rateKind != RateKind.None && retainRateYield) {
            uint256 backing = _backingInner(token, reserved);
            return (shares * backing) / totalShares;
        }
        if (rateKind != RateKind.None && convertYieldToHype && !retainRateYield) {
            // Last exit: pay everything left, including unharvested yield in kind.
            if (shares == totalShares) return free;
            uint256 backing = _backingInner(token, reserved);
            return (shares * backing) / totalShares;
        }
        return (shares * free) / totalShares;
    }

    /// @dev After a new deposit of `assets` is already in the box.
    function _sharesForAssets(IERC20 token, uint256 assets, uint256 totalShares, uint256 reserved)
        internal
        view
        returns (uint256)
    {
        if (assets == 0) return 0;
        if (rateKind == RateKind.None || totalShares == 0) return assets;
        uint256 backing = _backingInner(token, reserved);
        uint256 prev = backing > assets ? backing - assets : 0;
        if (prev == 0) return assets;
        return (assets * totalShares) / prev;
    }

    /// @dev Inner surplus = balance − reserved principal. Side tokens: full balance.
    function _pullYield(IERC20 token, IERC20 inner, uint256 reserved, address to) internal returns (uint256 amt) {
        if (address(token) == address(inner)) {
            uint256 bal = token.balanceOf(address(this));
            if (bal <= reserved) revert NoYield();
            amt = bal - reserved;
            lastAccounted = reserved;
        } else {
            amt = token.balanceOf(address(this));
            if (amt == 0) revert NoYield();
        }
        token.safeTransfer(to, amt);
        emit YieldPulled(address(token), to, amt);
    }

    function _setRetainRateYield(bool retain) internal {
        retainRateYield = retain;
        emit RetainRateYieldSet(retain);
    }

    function _setRateKind(IERC20 token, RateKind kind) internal {
        rateKind = kind;
        if (kind == RateKind.None) {
            lastAccounted += accruedRateYield;
            accruedRateYield = 0;
            lastRate = 0;
            emit RateFeedSet(kind, 0);
            return;
        }
        uint256 rate = _readRate(token);
        lastRate = rate;
        emit RateFeedSet(kind, rate);
    }

    function _readRate(IERC20 token) internal view returns (uint256 rate) {
        if (rateKind == RateKind.ExchangeRate) {
            (bool ok, bytes memory ret) = address(token).staticcall(abi.encodeWithSignature("exchangeRate()"));
            if (!ok || ret.length < 32) revert BadRateFeed();
            rate = abi.decode(ret, (uint256));
        } else if (rateKind == RateKind.ConvertToAssets) {
            (bool ok, bytes memory ret) =
                address(token).staticcall(abi.encodeWithSignature("convertToAssets(uint256)", uint256(1e18)));
            if (!ok || ret.length < 32) revert BadRateFeed();
            rate = abi.decode(ret, (uint256));
        } else if (rateKind == RateKind.GetPooledAvaxByShares) {
            (bool ok, bytes memory ret) =
                address(token).staticcall(abi.encodeWithSignature("getPooledAvaxByShares(uint256)", uint256(1e18)));
            if (!ok || ret.length < 32) revert BadRateFeed();
            rate = abi.decode(ret, (uint256));
        }
        if (rate == 0) revert BadRateFeed();
    }

    /// @dev Unrealized surplus on principal only. Floor so dust stays in lastAccounted.
    function _unaccruedRateYield(IERC20 token) internal view returns (uint256 add, uint256 rate) {
        if (rateKind == RateKind.None) return (0, 0);
        rate = _readRate(token);
        if (lastRate == 0 || lastAccounted == 0 || rate <= lastRate) return (0, rate);
        add = (lastAccounted * (rate - lastRate)) / rate;
    }

    function pendingRateYield(IERC20 token) public view returns (uint256) {
        (uint256 add,) = _unaccruedRateYield(token);
        return accruedRateYield + add;
    }

    /// @dev Move rate delta on `lastAccounted` into `accruedRateYield`.
    ///      Retain: book 1% of surplus, pin watermark, then flush to converter if convert is on.
    ///      Halt (convert off): book only — wrap/redeem stay live, new deposits mint at post-fee NAV.
    ///      Slash lowers the watermark and pulls nothing. Donations never enter lastAccounted.
    function _accrueRateYield(IERC20 token) internal {
        if (rateKind == RateKind.None) return;
        if (retainRateYield) {
            _bookRetainFee(token);
            _flushAccrued(token, 0, converter);
            return;
        }
        if (!convertYieldToHype) return;
        uint256 rate = _readRate(token);
        if (lastRate == 0) {
            lastRate = rate;
            return;
        }
        if (rate < lastRate) {
            lastRate = rate;
            return;
        }
        if (rate == lastRate) return;
        uint256 add = (lastAccounted * (rate - lastRate)) / rate;
        lastAccounted -= add;
        accruedRateYield += add;
        lastRate = rate;
        emit RateYieldAccrued(add, accruedRateYield, rate);
    }

    /// @dev Pin lastRate. On increase, 1% of surplus → accrued (not 100%). Dust fee stays with holders.
    function _bookRetainFee(IERC20 token) internal {
        uint256 rate = _readRate(token);
        if (lastRate == 0) {
            lastRate = rate;
            return;
        }
        if (rate < lastRate) {
            lastRate = rate;
            return;
        }
        if (rate == lastRate || lastAccounted == 0) return;
        uint256 add = (lastAccounted * (rate - lastRate)) / rate;
        lastRate = rate;
        uint256 fee = (add * YIELD_FEE_BPS) / BPS_DENOMINATOR;
        if (fee == 0) return;
        if (fee > lastAccounted) fee = lastAccounted;
        lastAccounted -= fee;
        accruedRateYield += fee;
        emit RateYieldAccrued(fee, accruedRateYield, rate);
    }

    function _flushAccrued(IERC20 token, uint256 reserved, address to) internal returns (uint256 amt) {
        if (to == address(0) || !convertYieldToHype || accruedRateYield == 0) return 0;
        uint256 bal = token.balanceOf(address(this));
        uint256 free = bal > reserved ? bal - reserved : 0;
        amt = accruedRateYield;
        if (amt > free) amt = free;
        if (amt == 0) return 0;
        accruedRateYield -= amt;
        token.safeTransfer(to, amt);
        emit RateYieldPulled(to, amt, lastRate);
    }

    /// @dev retain: pull 1% of surplus (protocol). 99% stays, so LP/lend keep the yield.
    ///      sell-all: pull 100% of surplus to converter; 99/1 is WHYPE at notify.
    function _tryPullRateYield(IERC20 token, uint256 reserved, address to) internal returns (uint256 surplus) {
        if (rateKind == RateKind.None || to == address(0)) return 0;
        if (retainRateYield) {
            _bookRetainFee(token);
            return _flushAccrued(token, reserved, to);
        }
        if (!convertYieldToHype) return 0;
        _accrueRateYield(token);
        surplus = accruedRateYield;
        if (surplus == 0) return 0;
        uint256 bal = token.balanceOf(address(this));
        uint256 free = bal > reserved ? bal - reserved : 0;
        uint256 cap_ = free > lastAccounted ? free - lastAccounted : 0;
        if (surplus > cap_) surplus = cap_;
        if (surplus == 0) return 0;
        accruedRateYield -= surplus;
        token.safeTransfer(to, surplus);
        emit RateYieldPulled(to, surplus, lastRate);
    }

    function _reducePrincipal(uint256 shares, uint256 totalShares) internal {
        if (shares == 0 || totalShares == 0) return;
        if (shares == totalShares) {
            lastAccounted = 0;
            // Retain: leftover accrued is protocol 1% still in the box (flush later).
            if (!retainRateYield) accruedRateYield = 0;
            return;
        }
        uint256 principalOut = (shares * lastAccounted) / totalShares;
        lastAccounted -= principalOut;
    }
}
