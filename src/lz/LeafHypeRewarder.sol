// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ILeafHypeRewarder, ILeafOFTRewardBind} from "./ILeafHypeRewarder.sol";

/// @title LeafHypeRewarder
/// @notice HyperEVM HYPE (WHYPE) distributor. 1% protocol / 99% holders.
///         Keeper converts source-chain yield → WHYPE, then `notify`.
///         hToken transfers settle like MasterChef (see LeafOFT._update).
///         99% is allocated over totalSupply, including contracts that never
///         claim (AMM/lending/CEX). That is leftover in this contract, not
///         redistributed. See docs/HYPE_COMPOSABILITY.md.
contract LeafHypeRewarder is Ownable2Step, ReentrancyGuard, ILeafHypeRewarder {
    using SafeERC20 for IERC20;

    uint16 public constant FEE_BPS = 100;
    uint16 public constant BPS = 10_000;

    IERC20 public immutable hype;
    address public feeRecipient;

    struct Pool {
        address hToken;
        uint256 accHypePerShare;
        bool exists;
    }

    mapping(bytes32 id => Pool) public pools;
    mapping(address hToken => bytes32 id) public idOfToken;
    mapping(bytes32 id => mapping(address user => uint256 debt)) public rewardDebt;
    mapping(bytes32 id => mapping(address user => uint256 stored)) public accrued;

    event Registered(bytes32 indexed id, address hToken);
    event FeeRecipientUpdated(address indexed recipient);
    event Notified(bytes32 indexed id, uint256 gross, uint256 fee, uint256 distributed);
    event Claimed(bytes32 indexed id, address indexed user, address indexed to, uint256 amount);

    error ZeroAddress();
    error UnknownPool();
    error OnlyHToken();
    error AlreadyRegistered();
    error NoSupply();
    error DustNotify();
    error ListingMismatch();
    error TokenAlreadyRegistered();

    constructor(address hype_, address owner_, address feeRecipient_) Ownable(owner_) {
        if (hype_ == address(0) || owner_ == address(0) || feeRecipient_ == address(0)) revert ZeroAddress();
        hype = IERC20(hype_);
        feeRecipient = feeRecipient_;
    }

    function setFeeRecipient(address recipient) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        feeRecipient = recipient;
        emit FeeRecipientUpdated(recipient);
    }

    /// @notice One listing id ↔ one LeafOFT. OFT.setHypeRewarder(this, id) first.
    function register(bytes32 id, address hToken) external onlyOwner {
        if (hToken == address(0) || id == bytes32(0)) revert ZeroAddress();
        if (pools[id].exists) revert AlreadyRegistered();
        if (idOfToken[hToken] != bytes32(0)) revert TokenAlreadyRegistered();
        ILeafOFTRewardBind oft = ILeafOFTRewardBind(hToken);
        if (oft.hypeRewarder() != address(this)) revert ListingMismatch();
        if (oft.listingId() != id) revert ListingMismatch();
        pools[id] = Pool(hToken, 0, true);
        idOfToken[hToken] = id;
        emit Registered(id, hToken);
    }

    /// @notice Smallest `amount` `notify` will accept at current supply.
    ///         Keeper: if harvested WHYPE is below this, wait. Do not retry dust.
    function minNotify(bytes32 id) public view returns (uint256) {
        Pool storage p = pools[id];
        if (!p.exists) revert UnknownPool();
        uint256 supply = IERC20(p.hToken).totalSupply();
        if (supply == 0) revert NoSupply();
        uint256 minDist = (supply + 1e18 - 1) / 1e18;
        if (minDist == 0) minDist = 1;
        uint256 amount = (minDist * BPS) / (BPS - FEE_BPS);
        if (amount == 0) amount = 1;
        while (amount - (amount * FEE_BPS) / BPS < minDist) {
            unchecked {
                ++amount;
            }
        }
        return amount;
    }

    /// @notice Pull WHYPE from caller, take 1%, credit 99% to current hToken supply.
    ///         Reverts `DustNotify` when `amount` < `minNotify(id)` (acc would not increase).
    function notify(bytes32 id, uint256 amount) external nonReentrant {
        Pool storage p = pools[id];
        if (!p.exists) revert UnknownPool();
        if (amount == 0) return;
        uint256 supply = IERC20(p.hToken).totalSupply();
        if (supply == 0) revert NoSupply();
        uint256 fee = (amount * FEE_BPS) / BPS;
        uint256 dist = amount - fee;
        if (dist > 0 && (dist * 1e18) / supply == 0) revert DustNotify();
        hype.safeTransferFrom(msg.sender, address(this), amount);
        if (fee > 0) hype.safeTransfer(feeRecipient, fee);
        if (dist == 0) {
            emit Notified(id, amount, fee, 0);
            return;
        }
        p.accHypePerShare += (dist * 1e18) / supply;
        emit Notified(id, amount, fee, dist);
    }

    function settle(bytes32 id, address user) public {
        if (!pools[id].exists) revert UnknownPool();
        _accrue(id, user);
    }

    function updateDebt(bytes32 id, address user) external {
        Pool storage p = pools[id];
        if (!p.exists) revert UnknownPool();
        if (msg.sender != p.hToken) revert OnlyHToken();
        rewardDebt[id][user] = _calDebt(p, user);
    }

    function claim(bytes32 id, address to) external nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (!pools[id].exists) revert UnknownPool();
        _accrue(id, msg.sender);
        uint256 amount = accrued[id][msg.sender];
        accrued[id][msg.sender] = 0;
        if (amount > 0) hype.safeTransfer(to, amount);
        emit Claimed(id, msg.sender, to, amount);
    }

    function pending(bytes32 id, address user) external view returns (uint256) {
        Pool storage p = pools[id];
        if (!p.exists) return 0;
        uint256 bal = IERC20(p.hToken).balanceOf(user);
        uint256 earned = (bal * p.accHypePerShare) / 1e18;
        uint256 debt = rewardDebt[id][user];
        uint256 extra = earned > debt ? earned - debt : 0;
        return accrued[id][user] + extra;
    }

    function _accrue(bytes32 id, address user) internal {
        if (user == address(0)) return;
        Pool storage p = pools[id];
        uint256 earned = (IERC20(p.hToken).balanceOf(user) * p.accHypePerShare) / 1e18;
        uint256 debt = rewardDebt[id][user];
        if (earned > debt) accrued[id][user] += earned - debt;
        rewardDebt[id][user] = earned;
    }

    function _calDebt(Pool storage p, address user) internal view returns (uint256) {
        return (IERC20(p.hToken).balanceOf(user) * p.accHypePerShare) / 1e18;
    }
}
