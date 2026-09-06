// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ILeafRewardSource} from "./ILeafRewardSource.sol";

/// @title LeafCallRewardSource
/// @notice Owner-set target+payload for protocol-specific claim (Squid, BLUAI).
///         Payload must credit `lockbox`. No swap. No inner principal move.
contract LeafCallRewardSource is Ownable2Step, ILeafRewardSource {
    address public immutable lockbox;
    address public target;
    bytes public payload;

    error OnlyLockbox();
    error CallFailed();
    error ZeroAddress();

    event TargetSet(address indexed target, bytes payload);

    constructor(address lockbox_, address owner_) Ownable(owner_) {
        if (lockbox_ == address(0) || owner_ == address(0)) revert ZeroAddress();
        lockbox = lockbox_;
    }

    function setCall(address target_, bytes calldata payload_) external onlyOwner {
        if (target_ == address(0)) revert ZeroAddress();
        target = target_;
        payload = payload_;
        emit TargetSet(target_, payload_);
    }

    /// @notice Anyone pays gas. Payload must credit `lockbox` and not take inner.
    function harvest(address lockbox_) external {
        if (lockbox_ != lockbox) revert OnlyLockbox();
        address t = target;
        if (t == address(0)) return;
        (bool ok,) = t.call(payload);
        if (!ok) revert CallFailed();
    }
}
