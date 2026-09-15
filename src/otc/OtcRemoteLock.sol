// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IOtcMailbox} from "./IOtcMailbox.sol";

/// @notice Source-chain lockbox. User locks `underlying` 1:1; mailbox mints the HyperEVM claim.
///         Redeem burns the claim and releases underlying here. No inventory, no premium capture.
contract OtcRemoteLock is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable underlying;
    IOtcMailbox public mailbox;
    uint256 public totalLocked;

    error Zero();
    error AlreadySet();
    error NotMailbox();

    event MailboxSet(address mailbox);
    event Deposited(address indexed from, address indexed destTo, uint256 amount);
    event Released(address indexed to, uint256 amount);

    constructor(address owner_, IERC20 underlying_) Ownable(owner_) {
        if (owner_ == address(0) || address(underlying_) == address(0)) revert Zero();
        underlying = underlying_;
    }

    function setMailbox(address m) external onlyOwner {
        if (address(mailbox) != address(0)) revert AlreadySet();
        if (m == address(0)) revert Zero();
        mailbox = IOtcMailbox(m);
        emit MailboxSet(m);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function deposit(uint256 amount, address destTo) external whenNotPaused nonReentrant {
        if (amount == 0 || destTo == address(0)) revert Zero();
        if (address(mailbox) == address(0)) revert Zero();
        underlying.safeTransferFrom(msg.sender, address(this), amount);
        totalLocked += amount;
        emit Deposited(msg.sender, destTo, amount);
        mailbox.notifyDeposit(destTo, amount);
    }

    function release(address to, uint256 amount) external nonReentrant {
        if (msg.sender != address(mailbox)) revert NotMailbox();
        if (to == address(0) || amount == 0) revert Zero();
        if (amount > totalLocked) revert Zero();
        unchecked {
            totalLocked -= amount;
        }
        underlying.safeTransfer(to, amount);
        emit Released(to, amount);
    }
}
