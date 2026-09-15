// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IOtcMailbox} from "./IOtcMailbox.sol";
import {OtcRemoteLock} from "./OtcRemoteLock.sol";
import {OtcClaim} from "./OtcClaim.sol";

/// @notice Kernel mailbox: lock and claim on the same EVM (tests + canary).
///         Production Arc corridor replaces this with an LZ/CCTP adapter that
///         implements the same two notify functions. Do not use across two
///         live chains — a message failure would mint without a lock.
contract OtcSameChainMailbox is IOtcMailbox, Ownable2Step {
    OtcRemoteLock public lock;
    OtcClaim public claim;

    error Zero();
    error AlreadySet();
    error NotLock();
    error NotClaim();

    constructor(address owner_) Ownable(owner_) {
        if (owner_ == address(0)) revert Zero();
    }

    function setEnds(address lock_, address claim_) external onlyOwner {
        if (address(lock) != address(0) || address(claim) != address(0)) revert AlreadySet();
        if (lock_ == address(0) || claim_ == address(0)) revert Zero();
        lock = OtcRemoteLock(lock_);
        claim = OtcClaim(claim_);
    }

    function notifyDeposit(address destTo, uint256 amount) external {
        if (msg.sender != address(lock)) revert NotLock();
        claim.mint(destTo, amount);
    }

    function notifyRedeem(address srcTo, uint256 amount) external {
        if (msg.sender != address(claim)) revert NotClaim();
        lock.release(srcTo, amount);
    }
}
