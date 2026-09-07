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
    mapping(address token => uint256 accounted) public lastAccountedToken;

    bool public convertYieldToHype;
    address public harvester;
    /// @dev pullYield destination. Harvester cannot redirect surplus to self.
    address public converter;
    mapping(address target => bool) public claimTarget;
    mapping(address target => bytes4 selector) public claimSelector;
    /// @dev e.g. xSQUID `claimRewards(address,uint256)` = 0x9a99b4f0. Forced args: (this, max).
    bytes4 public rewardsSelector;

    event ConvertModeSet(bool enabled);
    event HarvesterSet(address indexed harvester);
    event ConverterSet(address indexed converter);
    event ClaimTargetSet(address indexed target, bool allowed);
    event ClaimCallSet(address indexed target, bytes4 selector);
    event RewardsSelectorSet(bytes4 selector);
    event YieldPulled(address indexed token, address indexed to, uint256 amount);
    event FeeRecipientUpdated(address indexed recipient);
    event YieldHarvested(address indexed token, uint256 yieldAmount, uint256 fee);

    error NotHarvester();
    error NoYield();
    error BadConverter();
    error BadClaimTarget();
    error BadClaimSelector();
    error ClaimFailed();

    error FeeRecipientZero();

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

    function _setClaimTarget(address inner, address t, bool allowed) internal {
        if (t == address(0) || t == inner) revert BadClaimTarget();
        claimTarget[t] = allowed;
        if (!allowed) claimSelector[t] = bytes4(0);
        emit ClaimTargetSet(t, allowed);
    }

    function _setClaimCall(address inner, address t, bytes4 selector) internal {
        if (selector == bytes4(0)) revert BadClaimSelector();
        _setClaimTarget(inner, t, true);
        claimSelector[t] = selector;
        emit ClaimCallSet(t, selector);
    }

    /// @dev Anyone. Target + selector must match. Campaign must pay this lockbox.
    function _pokeClaim(address inner, address t, bytes calldata data) internal {
        if (!claimTarget[t] || t == inner) revert BadClaimTarget();
        if (data.length < 4) revert BadClaimSelector();
        bytes4 sel = bytes4(data[0:4]);
        if (claimSelector[t] == bytes4(0) || sel != claimSelector[t]) revert BadClaimSelector();
        (bool ok,) = t.call{value: msg.value}(data);
        if (!ok) revert ClaimFailed();
    }

    function _setRewardsSelector(bytes4 s) internal {
        rewardsSelector = s;
        emit RewardsSelectorSet(s);
    }

    /// @dev Claims as this lockbox. Selector must be rewards, not redeem — same
    ///      arity as Squid redeem, different 4 bytes (0x9a99b4f0 vs redeem).
    function _pokeRewards(address inner) internal {
        bytes4 s = rewardsSelector;
        if (s == bytes4(0) || inner == address(0)) revert BadClaimTarget();
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
        fee = (y * YIELD_FEE_BPS) / BPS_DENOMINATOR;
        if (fee > 0) {
            token.safeTransfer(feeRecipient, fee);
            free -= fee;
        }
        lastAccounted = free;
        emit YieldHarvested(address(token), y, fee);
    }

    function _harvestOther(IERC20 token) internal returns (uint256 fee) {
        if (convertYieldToHype) return 0;
        uint256 bal = token.balanceOf(address(this));
        uint256 last = lastAccountedToken[address(token)];
        if (bal <= last) return 0;
        uint256 y = bal - last;
        fee = (y * YIELD_FEE_BPS) / BPS_DENOMINATOR;
        if (fee > 0) token.safeTransfer(feeRecipient, fee);
        lastAccountedToken[address(token)] = token.balanceOf(address(this));
        emit YieldHarvested(address(token), y, fee);
    }

    function _assetsForShares(IERC20 token, uint256 shares, uint256 totalShares, uint256 reserved)
        internal
        view
        returns (uint256)
    {
        if (shares == 0 || totalShares == 0) return 0;
        if (convertYieldToHype) return shares;
        uint256 bal = token.balanceOf(address(this));
        uint256 free = bal > reserved ? bal - reserved : 0;
        return (shares * free) / totalShares;
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
            lastAccountedToken[address(token)] = 0;
            if (amt == 0) revert NoYield();
        }
        token.safeTransfer(to, amt);
        emit YieldPulled(address(token), to, amt);
    }
}
