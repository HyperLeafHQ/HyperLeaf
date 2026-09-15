// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IOtcMailbox} from "./IOtcMailbox.sol";

/// @notice HyperEVM claim for a remote lock. Decimals match the source token.
///         List this vs HyperEVM USDC on Leaf Market. Not a yield Leaf.
contract OtcClaim is Ownable2Step, Pausable, ReentrancyGuard {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    IOtcMailbox public mailbox;
    address public guardian;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    error Zero();
    error AlreadySet();
    error NotMailbox();
    error Insufficient();
    error NotGuardian();

    event MailboxSet(address mailbox);
    event GuardianSet(address guardian);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Minted(address indexed to, uint256 amount);
    event Redeemed(address indexed from, address indexed srcTo, uint256 amount);

    constructor(address owner_, address guardian_, string memory name_, string memory symbol_, uint8 decimals_)
        Ownable(owner_)
    {
        if (owner_ == address(0) || guardian_ == address(0)) revert Zero();
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
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

    function pause() external {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardian();
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) external whenNotPaused {
        if (msg.sender != address(mailbox)) revert NotMailbox();
        if (to == address(0) || amount == 0) revert Zero();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
        emit Minted(to, amount);
    }

    function redeem(uint256 amount, address srcTo) external payable whenNotPaused nonReentrant {
        if (amount == 0 || srcTo == address(0)) revert Zero();
        if (address(mailbox) == address(0)) revert Zero();
        uint256 b = balanceOf[msg.sender];
        if (b < amount) revert Insufficient();
        unchecked {
            balanceOf[msg.sender] = b - amount;
            totalSupply -= amount;
        }
        emit Transfer(msg.sender, address(0), amount);
        emit Redeemed(msg.sender, srcTo, amount);
        mailbox.notifyRedeem{value: msg.value}(srcTo, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) {
            if (a < amount) revert Insufficient();
            unchecked {
                allowance[from][msg.sender] = a - amount;
            }
        }
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert Zero();
        uint256 b = balanceOf[from];
        if (b < amount) revert Insufficient();
        unchecked {
            balanceOf[from] = b - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}
