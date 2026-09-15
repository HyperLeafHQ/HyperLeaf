// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
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
    uint8 public immutable decimals;
    IOtcMailbox public mailbox;
    address public guardian;
    uint256 public totalLocked;
    uint256 public maxLocked; // 0 = unlimited

    error Zero();
    error AlreadySet();
    error NotMailbox();
    error NotGuardian();
    error Cap();

    event MailboxSet(address mailbox);
    event GuardianSet(address guardian);
    event MaxLockedSet(uint256 cap);
    event Deposited(address indexed from, address indexed destTo, uint256 amount);
    event Released(address indexed to, uint256 amount);

    modifier onlyGuardian() {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardian();
        _;
    }

    constructor(address owner_, address guardian_, IERC20 underlying_) Ownable(owner_) {
        if (owner_ == address(0) || guardian_ == address(0) || address(underlying_) == address(0)) revert Zero();
        underlying = underlying_;
        decimals = IERC20Metadata(address(underlying_)).decimals();
        guardian = guardian_;
    }

    function setMailbox(address m) external onlyOwner {
        if (address(mailbox) != address(0)) revert AlreadySet();
        if (m == address(0)) revert Zero();
        mailbox = IOtcMailbox(m);
        emit MailboxSet(m);
    }

    function setGuardian(address g) external onlyOwner {
        if (g == address(0)) revert Zero();
        guardian = g;
        emit GuardianSet(g);
    }

    function setMaxLocked(uint256 cap) external onlyOwner {
        maxLocked = cap;
        emit MaxLockedSet(cap);
    }

    function pause() external onlyGuardian {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function deposit(uint256 amount, address destTo) external payable whenNotPaused nonReentrant {
        if (amount == 0 || destTo == address(0)) revert Zero();
        if (address(mailbox) == address(0)) revert Zero();
        if (maxLocked != 0 && totalLocked + amount > maxLocked) revert Cap();
        underlying.safeTransferFrom(msg.sender, address(this), amount);
        totalLocked += amount;
        emit Deposited(msg.sender, destTo, amount);
        mailbox.notifyDeposit{value: msg.value}(destTo, amount);
    }

    function release(address to, uint256 amount) external nonReentrant {
        if (msg.sender != address(mailbox)) revert NotMailbox();
        if (to == address(0) || amount == 0) revert Zero();
        if (amount > totalLocked) revert Cap();
        unchecked {
            totalLocked -= amount;
        }
        underlying.safeTransfer(to, amount);
        emit Released(to, amount);
    }
}
