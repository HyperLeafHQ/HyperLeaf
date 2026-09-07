// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LeafInboundLockbox} from "./LeafInboundLockbox.sol";
import {IVirtualsStake} from "./IVirtualsStake.sol";

/// @title LeafVirtualsLockbox
/// @notice C1 for hVIRTUALMAX. Deposited VIRTUAL is staked with Auto Max-lock
///         (104 weeks, autoRenew=true). No protocol redeem. No toggleAutoRenew.
contract LeafVirtualsLockbox is LeafInboundLockbox {
    using SafeERC20 for IERC20;

    IVirtualsStake public immutable virtuals;
    uint8 public constant MAX_WEEKS = 104;

    constructor(
        address token_,
        address virtuals_,
        address endpoint_,
        address owner_,
        address guardian_,
        address feeRecipient_,
        uint256 depositCap_
    ) LeafInboundLockbox(token_, endpoint_, owner_, guardian_, feeRecipient_, depositCap_) {
        if (virtuals_ == address(0)) revert ZeroAddress();
        virtuals = IVirtualsStake(virtuals_);
    }

    function _afterDeposit(uint256 got) internal override {
        uint256 before = innerToken.balanceOf(address(this));
        innerToken.forceApprove(address(virtuals), got);
        virtuals.stake(got, MAX_WEEKS, true);
        if (innerToken.balanceOf(address(this)) >= before) revert BadStake();
    }

    function setClaimTarget(address t, bool allowed) public override onlyOwner {
        if (t == address(virtuals)) revert BadClaimTarget();
        _setClaimTarget(address(innerToken), t, allowed);
    }

    function setClaimCall(address t, bytes4 selector) public override onlyOwner {
        if (t == address(virtuals)) revert BadClaimTarget();
        _setClaimCall(address(innerToken), t, selector);
    }
}
