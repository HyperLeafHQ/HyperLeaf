// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPremarketOriginMailbox {
    function notifyCredit(bytes32 seriesId, uint256 amount, address refundTo) external payable;
}

/// @notice Holds the official token on its native chain (Arb VAR, etc.).
///         Deliver here; HyperEVM only tracks credit. Redeem releases back to the holder here.
contract PremarketOriginLock is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    IPremarketOriginMailbox public mailbox;
    address public guardian;
    mapping(bytes32 => uint256) public locked;

    error Zero();
    error AlreadySet();
    error NotMailbox();
    error NotGuardian();
    error Cap();

    event MailboxSet(address mailbox);
    event Delivered(bytes32 indexed seriesId, address indexed from, uint256 amount);
    event Released(bytes32 indexed seriesId, address indexed to, uint256 amount);

    constructor(address owner_, address guardian_, IERC20 token_) Ownable(owner_) {
        if (owner_ == address(0) || guardian_ == address(0) || address(token_) == address(0)) revert Zero();
        token = token_;
        guardian = guardian_;
    }

    function setMailbox(address m) external onlyOwner {
        if (address(mailbox) != address(0)) revert AlreadySet();
        if (m == address(0)) revert Zero();
        mailbox = IPremarketOriginMailbox(m);
        emit MailboxSet(m);
    }

    function pause() external {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardian();
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function deliver(bytes32 seriesId, uint256 amount, address refundTo) external payable whenNotPaused nonReentrant {
        if (seriesId == bytes32(0) || amount == 0 || refundTo == address(0)) revert Zero();
        token.safeTransferFrom(msg.sender, address(this), amount);
        locked[seriesId] += amount;
        emit Delivered(seriesId, msg.sender, amount);
        mailbox.notifyCredit{value: msg.value}(seriesId, amount, refundTo);
    }

    function release(bytes32 seriesId, address to, uint256 amount) external nonReentrant whenNotPaused {
        if (msg.sender != address(mailbox)) revert NotMailbox();
        if (to == address(0) || amount == 0) revert Zero();
        uint256 have = locked[seriesId];
        if (amount > have) revert Cap();
        unchecked {
            locked[seriesId] = have - amount;
        }
        token.safeTransfer(to, amount);
        emit Released(seriesId, to, amount);
    }
}
