// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LeafOApp} from "./LeafOApp.sol";
import {LeafYieldFee} from "./LeafYieldFee.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";

/// @title LeafRedeemQueue
/// @notice C2 source lockbox. 1% of new yield → feeRecipient. No fee on in/out.
///         Inbound lock+mint like L. Outbound burn on HyperEVM opens a ticket;
///         inner token is claimable after `redeemDelay`. Delay must be >= the
///         underlying protocol unstake. Do not use for C1.
contract LeafRedeemQueue is LeafOApp, ReentrancyGuard, LeafYieldFee {
    using SafeERC20 for IERC20;

    struct Ticket {
        address to;
        uint256 amount;
        uint64 eta;
        bool claimed;
    }

    IERC20 public immutable innerToken;
    uint64 public redeemDelay;
    uint256 public depositCap;
    uint256 public totalLocked;
    uint256 public pendingTicketAssets;
    uint256 public nextTicketId;
    mapping(uint256 id => Ticket) public tickets;

    event CapUpdated(uint256 cap);
    event BridgedOut(address indexed from, uint32 indexed dstEid, bytes32 to, uint256 amount, bytes32 guid);
    event RedeemQueued(uint256 indexed id, address indexed to, uint256 amount, uint64 eta, bytes32 guid);
    event RedeemClaimed(uint256 indexed id, address indexed to, uint256 amount);
    event RedeemDelayUpdated(uint64 delay);
    event CreditAborted(address indexed to, uint256 amount);

    error ZeroAmount();
    error CapExceeded();
    error InsufficientLocked();
    error NotMature();
    error AlreadyClaimed();
    error UnknownTicket();
    error CannotPullInner();
    error DelayTooLow();

    constructor(
        address token_,
        address endpoint_,
        address owner_,
        address guardian_,
        address feeRecipient_,
        uint256 depositCap_,
        uint64 redeemDelay_
    ) LeafOApp(endpoint_, owner_, guardian_) {
        if (token_ == address(0)) revert ZeroAddress();
        innerToken = IERC20(token_);
        depositCap = depositCap_;
        redeemDelay = redeemDelay_;
        _initFee(feeRecipient_);
    }

    function openBridge() public override onlyOwner {
        if (innerSupplyCeiling == 0) revert LimitsUnset();
        super.openBridge();
    }

    function canonicalInner() public view override returns (address) {
        return address(innerToken);
    }

    function setDepositCap(uint256 cap) external onlyOwner {
        if (depositCap != 0 && cap > depositCap) revert CapIncrease();
        depositCap = cap;
        emit CapUpdated(cap);
    }

    function abortCredit(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0) || amount == 0) revert ZeroAmount();
        if (health != Health.Halted && health != Health.Insolvent) revert NotSolvent();
        if (amount > totalLocked) revert InsufficientLocked();
        _requireCash(innerToken, amount, pendingTicketAssets);
        totalLocked -= amount;
        innerToken.safeTransfer(to, amount);
        _syncAccounted(innerToken, pendingTicketAssets);
        emit CreditAborted(to, amount);
    }

    function setFeeRecipient(address recipient) external onlyOwner {
        _setFeeRecipient(recipient);
    }

    function setConvertYieldToHype(bool enabled) external onlyOwner {
        _setConvertYieldToHype(enabled);
    }

    function setHarvester(address harvester_) external onlyOwner {
        _setHarvester(harvester_);
    }

    function setConverter(address converter_) external onlyOwner {
        _setConverter(converter_);
    }

    function setRewardsSelector(bytes4 s) external onlyOwner {
        if (totalLocked + pendingTicketAssets > 0) revert ConfigFrozen();
        _setRewardsSelector(s);
    }

    function pokeRewards() external payable nonReentrant {
        _pokeRewards(address(innerToken));
    }

    /// @notice Can only raise the wait. Existing tickets keep their eta.
    function setRedeemDelay(uint64 delay) external onlyOwner {
        if (delay < redeemDelay) revert DelayTooLow();
        redeemDelay = delay;
        emit RedeemDelayUpdated(delay);
    }

    function pullYield(IERC20 token, address to) external nonReentrant {
        _requireConverter(to);
        if (address(token) == address(innerToken)) revert CannotPullInner();
        _requireConvertOn();
        _pullYield(token, innerToken, totalLocked + pendingTicketAssets, to);
    }

    function harvest() external nonReentrant {
        _requireInnerSupplyOk(innerToken);
        _harvestInner(innerToken, pendingTicketAssets);
    }

    function send(uint32 dstEid, bytes32 to, uint256 amount, address refund)
        public
        payable
        nonReentrant
        whenNotPaused
        returns (bytes32 guid)
    {
        if (amount == 0) revert ZeroAmount();
        if (to == bytes32(0)) revert ZeroAddress();
        _requireMint();
        _requireInnerSupplyOk(innerToken);

        _harvestInner(innerToken, pendingTicketAssets);

        uint256 got = _pull(msg.sender, amount);
        if (totalLocked + got > depositCap) revert CapExceeded();
        totalLocked += got;
        _accountDeposit(got);

        _takeQuota(got);

        bytes memory payload = encodeBridge(to, got);
        ILayerZeroEndpointV2.MessagingReceipt memory receipt =
            _lzSend(dstEid, payload, _defaultOptions(), refund == address(0) ? msg.sender : refund);
        emit BridgedOut(msg.sender, dstEid, to, got, receipt.guid);
        return receipt.guid;
    }

    function sendTo(uint32 dstEid, address to, uint256 amount) external payable returns (bytes32) {
        return send(dstEid, bytes32(uint256(uint160(to))), amount, msg.sender);
    }

    /// @dev Claim stays available while paused so a halt does not trap mature exits.
    function claim(uint256 id) external nonReentrant {
        Ticket storage t = tickets[id];
        if (t.to == address(0)) revert UnknownTicket();
        if (t.claimed) revert AlreadyClaimed();
        if (block.timestamp < t.eta) revert NotMature();
        if (health == Health.Insolvent) revert NotSolvent();
        t.claimed = true;
        pendingTicketAssets -= t.amount;
        _requireCash(innerToken, t.amount, pendingTicketAssets);
        innerToken.safeTransfer(t.to, t.amount);
        emit RedeemClaimed(id, t.to, t.amount);
    }

    function _lzReceive(
        ILayerZeroEndpointV2.Origin calldata,
        bytes32 guid,
        bytes calldata message,
        address,
        bytes calldata
    ) internal override nonReentrant whenNotPaused {
        (bytes32 toB, uint256 amount) = _decodeBridge(message);
        address to = address(uint160(uint256(toB)));
        if (to == address(0) || amount == 0) revert ZeroAmount();
        if (amount > totalLocked) revert InsufficientLocked();
        _requireRedeem();
        _takeQuota(amount);
        if (innerToken.balanceOf(address(this)) < totalLocked + pendingTicketAssets) revert Underbacked();

        _harvestInner(innerToken, pendingTicketAssets);
        uint256 assetsOut = _assetsForShares(innerToken, amount, totalLocked, pendingTicketAssets);
        _requireCash(innerToken, assetsOut, pendingTicketAssets);
        totalLocked -= amount;
        pendingTicketAssets += assetsOut;
        uint256 id = nextTicketId++;
        uint64 eta = uint64(block.timestamp) + redeemDelay;
        tickets[id] = Ticket(to, assetsOut, eta, false);
        _syncAccounted(innerToken, pendingTicketAssets);
        emit RedeemQueued(id, to, assetsOut, eta, guid);
    }

    function _pull(address from, uint256 amount) internal returns (uint256 got) {
        uint256 before = innerToken.balanceOf(address(this));
        innerToken.safeTransferFrom(from, address(this), amount);
        got = innerToken.balanceOf(address(this)) - before;
        if (got == 0) revert ZeroAmount();
    }
}
