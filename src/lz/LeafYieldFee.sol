// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract LeafYieldFee {
    using SafeERC20 for IERC20;

    uint16 public constant YIELD_FEE_BPS = 100;
    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant RATE_SCALE = 1e18;

    address public feeRecipient;
    uint256 public lastAccounted;

    bool public convertYieldToHype;
    address public harvester;
    /// @dev pullYield destination. Harvester cannot redirect surplus to self.
    address public converter;
    /// @dev e.g. xSQUID `claimRewards(address,uint256)` = 0x9a99b4f0. Forced args: (this, max).
    bytes4 public rewardsSelector;
    /// @dev Umbrella: RewardsController. Zero = poke inner (Squid/Avantis).
    address public rewardsTarget;
    /// @dev RewardsController.claimAllRewards(address[],address)
    bytes4 public constant CLAIM_ALL_REWARDS = 0xbb492bf5;

    /// @dev Rate-bearing inner (cbETH `exchangeRate`, 4626 `convertToAssets(1e18)`,
    ///      BENQI sAVAX `getPooledAvaxByShares(1e18)`).
    ///
    ///      Rate yield is accounted in two units:
    ///      - lastAccounted / accruedRateYield remain inner-token units for cash accounting;
    ///      - rateCostBasis is normalized economic value at the asset's 1e18 rate scale.
    ///
    ///      Keeping an economic cost basis instead of moving the rate watermark downward is
    ///      what makes `1.00 -> 0.90 -> 1.00` a zero-yield recovery while also preventing
    ///      deposits made during the drawdown from inheriting the old loss.
    enum RateKind {
        None,
        ExchangeRate,
        ConvertToAssets,
        GetPooledAvaxByShares,
        RouterGetRate
    }

    RateKind public rateKind;
    /// @dev Last observed feed rate. Used for jump detection/telemetry, not as the economic HWM.
    uint256 public lastRate;
    /// @dev Identified rate yield, not yet pulled. Not principal. Not a donation.
    uint256 public accruedRateYield;
    /// @dev true = wstETH-style: 99% of rate surplus stays in the box (NAV in inner).
    ///      Only 1% is pulled to the converter (protocol fee -> HYPE).
    ///      false = sell the whole surplus to WHYPE and split 99/1 at notify.
    bool public retainRateYield;
    /// @dev Inner wei -> dest shares. 1 for 18-dec. 1e10 for LBTC 8-dec.
    uint256 public shareScale;
    /// @dev 0 = off. Else mint stops if getRate jumps more than this in one accrue.
    uint16 public maxRateJumpBps;
    bool public rateJumped;

    /// @dev Economic cost basis for the user-owned rate-bearing position.
    ///      Stored in the feed's normalized underlying-value units.
    uint256 public rateCostBasis;
    /// @dev Snapshot of total destination shares used by pending-rate-yield views.
    ///      Derived contracts must sync this after total share changes.
    uint256 public rateReferenceShares;

    event ConvertModeSet(bool enabled);
    event HarvesterSet(address indexed harvester);
    event ConverterSet(address indexed converter);
    event RewardsSelectorSet(bytes4 selector);
    event RewardsTargetSet(address indexed target);
    event RateFeedSet(RateKind kind, uint256 rate);
    event RateYieldAccrued(uint256 added, uint256 accrued, uint256 rate);
    event RateYieldPulled(address indexed to, uint256 surplus, uint256 rate);
    event RetainRateYieldSet(bool retain);
    event YieldPulled(address indexed token, address indexed to, uint256 amount);
    event FeeRecipientUpdated(address indexed recipient);
    event YieldHarvested(address indexed token, uint256 yieldAmount, uint256 fee);
    event RateJump(uint256 lastRate, uint256 newRate);
    event ShareScaleSet(uint256 scale);
    event MaxRateJumpSet(uint16 bps);

    error NotHarvester();
    error NoYield();
    error BadConverter();
    error ClaimFailed();
    error ForbiddenRewardsSelector();
    error BadRewardsTarget();
    error BadRateFeed();
    error FeeRecipientZero();
    error ConvertHalted();

    error RateJumpErr();

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
        return _forbiddenExitSelector(s) || _forbiddenLbtcSelector(s);
    }

    function _forbiddenExitSelector(bytes4 s) internal pure returns (bool) {
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
            || s == bytes4(0x38248a0c) // completeWithdrawal(bool) — sWBERA 7d NFT
            || s == bytes4(0x06866fdc) // completeWithdrawal(bool,uint256)
            || s == bytes4(0x1b0aed2c) // cancelQueuedWithdrawal (vault)
            || s == bytes4(0x041d5408) // cancelQueuedWithdrawal()
            || s == bytes4(0xc9d2ff9d) // requestUnlock(uint256) — BENQI sAVAX 15d
            || s == bytes4(0x2e1a7d4d) // withdraw(uint256) — BENQI claim AVAX / SOON 90d unlock
            || s == bytes4(0x1338736f) // lock(uint256,uint256) — SOON occupancy 0x6601, not gSOON vault
            || s == bytes4(0x6e553f65) // deposit(uint256,address) — ERC-4626; poke arity matches
            || s == bytes4(0x94bf804d) // mint(uint256,address)
            || s == bytes4(0x250201db) // cooldownOnBehalfOf(address) — Umbrella StakeToken
            || s == bytes4(0x397a1b28) // requestWithdraw(address,uint256) — ether.fi DelayedWithdraw arity
            || s == bytes4(0x0efe6a8b) // deposit(address,uint256,uint256) — sETHFI teller, never poke
            || s == bytes4(0x1d7d4ebc) // KING merkle claim(address,uint256,bytes32,bytes32[])
            || s == bytes4(0x2e7ba6ef); // ETHFI/EIGEN merkle claim(uint256,address,uint256,bytes32[])
    }

    function _forbiddenLbtcSelector(bytes4 s) internal pure returns (bool) {
        return s == bytes4(0x42966c68) // burn(uint256)
            || s == bytes4(0xbcf64e05) // burn(uint256,bytes32)
            || s == bytes4(0x6bc63893) // mint(bytes,bytes)
            || s == bytes4(0x8340f549) // deposit(address,address,uint256) — AssetRouter BTC.b→LBTC
            || s == bytes4(0xe5c1bf6e); // redeem(bytes,bytes) — 10d BTC
    }

    function _setRewardsTarget(address t) internal {
        rewardsTarget = t;
        emit RewardsTargetSet(t);
    }

    /// @dev Squid/Avantis: (this, max) on inner.
    ///      Umbrella: claimAllRewards([inner], this) on RewardsController — never inner.
    function _pokeRewards(address inner) internal {
        bytes4 s = rewardsSelector;
        if (s == bytes4(0) || inner == address(0)) revert ClaimFailed();
        if (_forbiddenRewardsSelector(s)) revert ForbiddenRewardsSelector();
        if (s == CLAIM_ALL_REWARDS) {
            address t = rewardsTarget;
            if (t == address(0) || t == inner) revert BadRewardsTarget();
            address[] memory assets = new address[](1);
            assets[0] = inner;
            (bool claimed,) = t.call{value: msg.value}(abi.encodeWithSelector(s, assets, address(this)));
            if (!claimed) revert ClaimFailed();
            return;
        }
        if (rewardsTarget != address(0)) revert BadRewardsTarget();
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
        if (rateKind == RateKind.None || totalShares == 0) {
            uint256 s = shareScale == 0 ? 1 : shareScale;
            return assets * s;
        }
        uint256 backing = _backingInner(token, reserved);
        uint256 prev = backing > assets ? backing - assets : 0;
        if (prev == 0) return 0;
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

    function _setShareScale(uint256 s) internal {
        if (s == 0) revert BadRateFeed();
        shareScale = s;
        emit ShareScaleSet(s);
    }

    function _setMaxRateJumpBps(uint16 bps) internal {
        maxRateJumpBps = bps;
        emit MaxRateJumpSet(bps);
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
            rateCostBasis = 0;
            rateReferenceShares = 0;
            emit RateFeedSet(kind, 0);
            return;
        }
        uint256 rate = _readRate(token);
        lastRate = rate;
        rateCostBasis = 0;
        rateReferenceShares = 0;
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
        } else if (rateKind == RateKind.RouterGetRate) {
            address t = rewardsTarget;
            if (t == address(0) || t == address(token)) revert BadRateFeed();
            (bool ok, bytes memory ret) = t.staticcall(abi.encodeWithSignature("getRate(address)", address(token)));
            if (!ok || ret.length < 32) revert BadRateFeed();
            rate = abi.decode(ret, (uint256));
        }
        if (rate == 0) revert BadRateFeed();
    }

    /// @dev |Δrate|/lastRate in bps. 0 if unset or equal.
    function _rateJumpBps(uint256 rate) internal view returns (uint256) {
        if (lastRate == 0 || rate == lastRate) return 0;
        uint256 delta = rate > lastRate ? rate - lastRate : lastRate - rate;
        return (delta * BPS_DENOMINATOR) / lastRate;
    }

    function _tripIfRateJump(uint256 rate) internal returns (bool) {
        if (maxRateJumpBps == 0) return false;
        uint256 jump = _rateJumpBps(rate);
        if (jump > maxRateJumpBps) {
            rateJumped = true;
            emit RateJump(lastRate, rate);
            return true;
        }
        return false;
    }

    /// @dev Convert destination shares into normalized economic value using the current rate.
    ///      shareScale cancels the inner-token decimal conversion between deposits and shares.
    function _rateValue(uint256 shares, uint256 rate) internal view returns (uint256) {
        if (shares == 0) return 0;
        if (shareScale == 0 || shareScale > type(uint256).max / RATE_SCALE) revert BadRateFeed();
        return Math.mulDiv(shares, rate, RATE_SCALE * shareScale);
    }

    function _rateValueOfTokens(uint256 assets, uint256 rate) internal pure returns (uint256) {
        if (assets == 0) return 0;
        return Math.mulDiv(assets, rate, RATE_SCALE);
    }

    function _reservedRateValue(uint256 rate) internal view returns (uint256) {
        if (accruedRateYield == 0) return 0;
        return _rateValueOfTokens(accruedRateYield, rate);
    }

    function _userRateValue(uint256 totalShares, uint256 rate) internal view returns (uint256) {
        uint256 gross = _rateValue(totalShares, rate);
        uint256 reservedValue = _reservedRateValue(rate);
        return gross > reservedValue ? gross - reservedValue : 0;
    }

    /// @notice Record the economic cost of a new rate-bearing deposit at the live feed rate.
    ///      A deposit during a drawdown therefore gets its own lower cost basis and cannot
    ///      inherit the historical loss carried by earlier shares.
    function _recordRateDeposit(uint256 assets) internal {
        if (rateKind == RateKind.None || assets == 0) return;
        uint256 rate = _readRate(IERC20(address(this)));
        rateCostBasis += _rateValueOfTokens(assets, rate);
    }

    function _syncRateShares(uint256 totalShares) internal {
        rateReferenceShares = totalShares;
    }

    /// @dev Unrealized *fee-bearing* rate yield in inner-token units.
    ///      Existing accruedRateYield is already reserved and is included in the result.
    function _unaccruedRateYield(IERC20 token) internal view returns (uint256 add, uint256 rate) {
        if (rateKind == RateKind.None) return (0, 0);
        rate = _readRate(token);
        if (lastRate == 0 || rateReferenceShares == 0 || rateCostBasis == 0) return (0, rate);
        if (maxRateJumpBps != 0 && _rateJumpBps(rate) > maxRateJumpBps) return (0, rate);

        uint256 userValue = _userRateValue(rateReferenceShares, rate);
        if (userValue <= rateCostBasis) return (0, rate);

        uint256 growth = userValue - rateCostBasis;
        if (retainRateYield) {
            uint256 feeValue = (growth * YIELD_FEE_BPS) / BPS_DENOMINATOR;
            add = Math.mulDiv(feeValue, RATE_SCALE, rate);
        } else {
            add = Math.mulDiv(growth, RATE_SCALE, rate);
        }
    }

    function pendingRateYield(IERC20 token) public view returns (uint256) {
        (uint256 add,) = _unaccruedRateYield(token);
        return accruedRateYield + add;
    }

    /// @dev Book rate growth against a fixed economic cost basis.
    ///      A rate decline never lowers the cost basis. Recovery is only fee-bearing after
    ///      the total user value exceeds that cost basis again.
    function _accrueRateYield(IERC20 token) internal {
        if (rateKind == RateKind.None) return;
        uint256 rate = _readRate(token);
        if (lastRate == 0) {
            lastRate = rate;
            return;
        }
        if (rate == lastRate) return;
        if (_tripIfRateJump(rate)) return;
        lastRate = rate;

        if (rateReferenceShares == 0 || rateCostBasis == 0) return;

        uint256 userValue = _userRateValue(rateReferenceShares, rate);
        if (userValue <= rateCostBasis) return;

        uint256 growth = userValue - rateCostBasis;
        if (retainRateYield) {
            uint256 feeValue = (growth * YIELD_FEE_BPS) / BPS_DENOMINATOR;
            uint256 feeTokens = Math.mulDiv(feeValue, RATE_SCALE, rate);
            if (feeTokens == 0) return;
            if (feeTokens > lastAccounted) feeTokens = lastAccounted;
            if (feeTokens == 0) return;

            uint256 feeValueBooked = Math.mulDiv(feeTokens, rate, RATE_SCALE);
            lastAccounted -= feeTokens;
            accruedRateYield += feeTokens;
            rateCostBasis = userValue - feeValueBooked;
            emit RateYieldAccrued(feeTokens, accruedRateYield, rate);
            return;
        }

        if (!convertYieldToHype) return;
        uint256 add = Math.mulDiv(growth, RATE_SCALE, rate);
        if (add == 0) return;
        if (add > lastAccounted) add = lastAccounted;
        if (add == 0) return;

        lastAccounted -= add;
        accruedRateYield += add;
        emit RateYieldAccrued(add, accruedRateYield, rate);
    }

    /// @dev Retain mode uses the same cost-basis model but books only the 1% protocol fee.
    ///      The remaining 99% becomes part of the holders' economic basis, so it is never
    ///      charged again at the same rate.
    function _bookRetainFee(IERC20 token) internal {
        uint256 rate = _readRate(token);
        if (lastRate == 0) {
            lastRate = rate;
            return;
        }
        if (rate == lastRate || rateReferenceShares == 0 || rateCostBasis == 0) return;
        if (_tripIfRateJump(rate)) return;
        lastRate = rate;

        uint256 userValue = _userRateValue(rateReferenceShares, rate);
        if (userValue <= rateCostBasis) return;

        uint256 growth = userValue - rateCostBasis;
        uint256 feeValue = (growth * YIELD_FEE_BPS) / BPS_DENOMINATOR;
        uint256 feeTokens = Math.mulDiv(feeValue, RATE_SCALE, rate);
        if (feeTokens == 0) return;
        if (feeTokens > lastAccounted) feeTokens = lastAccounted;
        if (feeTokens == 0) return;

        uint256 feeValueBooked = Math.mulDiv(feeTokens, rate, RATE_SCALE);
        lastAccounted -= feeTokens;
        accruedRateYield += feeTokens;
        rateCostBasis = userValue - feeValueBooked;
        emit RateYieldAccrued(feeTokens, accruedRateYield, rate);
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
        if (rateKind != RateKind.None && rateCostBasis > 0) {
            uint256 basisOut = Math.mulDiv(rateCostBasis, shares, totalShares);
            if (basisOut >= rateCostBasis || shares == totalShares) {
                rateCostBasis = 0;
            } else {
                rateCostBasis -= basisOut;
            }
        }

        if (shares == totalShares) {
            lastAccounted = 0;
            rateReferenceShares = 0;
            // Retain: leftover accrued is protocol 1% still in the box (flush later).
            if (!retainRateYield) accruedRateYield = 0;
            return;
        }
        uint256 principalOut = (shares * lastAccounted) / totalShares;
        lastAccounted -= principalOut;
        rateReferenceShares = totalShares - shares;
    }
}
