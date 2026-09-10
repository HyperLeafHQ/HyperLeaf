// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LeafOApp} from "./LeafOApp.sol";
import {LeafYieldFee} from "./LeafYieldFee.sol";
import {LeafB3Policy as P} from "./LeafB3Policy.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";

/// @title LeafB3Lockbox
/// @notice C1 source for hB3. Pulls B3, stakeFor(this, amt). Tokens leave to
///         EOA custody. Dest shares = B3 staked. No protocol redeem.
///         Claim/WIN stays unset — do not ship yield poke until a harvest tx
///         is pinned. Solvency proof is Staked events, not balanceOf(stake).
contract LeafB3Lockbox is LeafOApp, ReentrancyGuard, LeafYieldFee {
    using SafeERC20 for IERC20;

    IERC20 public immutable b3;
    address public immutable stake;
    address public immutable custody;
    address public claim;
    bool public winClaimEnabled;
    uint256 public depositCap;
    uint256 public totalLocked;

    event BridgedOut(address indexed from, uint32 indexed dstEid, bytes32 to, uint256 amount, bytes32 guid);
    event CapUpdated(uint256 cap);
    event ClaimSet(address claim, bytes4 sel);
    event CustodyShort(uint256 custodyBal, uint256 locked);

    error ZeroAmount();
    error CapExceeded();
    error InboundOnly();
    error BadStake();
    error ClaimUnset();
    error MinStake();

    constructor(
        address b3_,
        address stake_,
        address custody_,
        address endpoint_,
        address owner_,
        address guardian_,
        address feeRecipient_,
        uint256 depositCap_
    ) LeafOApp(endpoint_, owner_, guardian_) {
        if (b3_ == address(0) || stake_ == address(0) || custody_ == address(0)) revert ZeroAddress();
        b3 = IERC20(b3_);
        stake = stake_;
        custody = custody_;
        depositCap = depositCap_;
        _initFee(feeRecipient_);
    }

    function canonicalInner() public view override returns (address) {
        return address(b3);
    }

    function setDepositCap(uint256 cap) external onlyOwner {
        if (depositCap != 0 && cap > depositCap) revert CapIncrease();
        depositCap = cap;
        emit CapUpdated(cap);
    }

    /// @notice Records the upside.win delayed-withdrawal target. Off until a
    ///         lockbox-as-user request actually pays this contract.
    function setClaim(address claim_, bytes4 sel) external onlyOwner {
        if (claim_ == address(0)) revert ClaimUnset();
        if (P.isUnstake(sel) || sel == P.STAKE_FOR) revert P.UnstakeForbidden();
        if (sel != P.CLAIM_DELAYED_WITHDRAWAL) revert P.WrongStake();
        if (block.chainid == 8453 && claim_ != P.CLAIM) revert P.WrongStake();
        claim = claim_;
        emit ClaimSet(claim_, sel);
    }

    function setWinClaimEnabled(bool on) external onlyOwner {
        if (on && claim == address(0)) revert ClaimUnset();
        winClaimEnabled = on;
    }

    /// @notice Keeper supplies the per-user request index (not the UI global id).
    ///         Live example: calldata index 5, event Request ID 1431.
    ///         Received B3 is yield — do not add to totalLocked.
    function claimWin(uint256 index) external nonReentrant {
        if (!winClaimEnabled || claim == address(0)) revert ClaimUnset();
        (bool ok,) = claim.call(abi.encodeWithSelector(P.CLAIM_DELAYED_WITHDRAWAL, index));
        if (!ok) revert BadStake();
    }

    function send(uint32 dstEid, bytes32 to, uint256 amount, address refund)
        public
        payable
        nonReentrant
        whenNotPaused
        returns (bytes32 guid)
    {
        if (amount == 0) revert ZeroAmount();
        if (amount < P.MIN_STAKE) revert MinStake();
        if (to == bytes32(0)) revert ZeroAddress();
        _requireMint();
        _requireInnerSupplyOk(b3);

        uint256 before = b3.balanceOf(address(this));
        b3.safeTransferFrom(msg.sender, address(this), amount);
        uint256 got = b3.balanceOf(address(this)) - before;
        if (got == 0) revert ZeroAmount();
        if (totalLocked + got > depositCap) revert CapExceeded();

        b3.forceApprove(stake, got);
        (bool ok,) = stake.call(abi.encodeWithSelector(P.STAKE_FOR, address(this), got));
        b3.forceApprove(stake, 0);
        if (!ok || b3.balanceOf(address(this)) != before) revert BadStake();

        totalLocked += got;
        _takeQuota(got);

        bytes memory payload = encodeBridge(to, got);
        ILayerZeroEndpointV2.MessagingReceipt memory receipt =
            _lzSend(dstEid, payload, _defaultOptions(dstEid), refund == address(0) ? msg.sender : refund);
        emit BridgedOut(msg.sender, dstEid, to, got, receipt.guid);
        return receipt.guid;
    }

    function sendTo(uint32 dstEid, address to, uint256 amount) external payable returns (bytes32) {
        return send(dstEid, bytes32(uint256(uint160(to))), amount, msg.sender);
    }

    /// @notice Weak watch: EOA can hold other users' B3. If custody < our
    ///         locked, something left. Never treat this as a solvency proof.
    function reportCustody() external {
        uint256 bal = b3.balanceOf(custody);
        if (bal < totalLocked) {
            emit CustodyShort(bal, totalLocked);
            if (uint8(health) < uint8(Health.Degraded)) {
                health = Health.Degraded;
                emit HealthSet(Health.Degraded, msg.sender);
            }
        }
    }

    function pokeRewards() external payable {
        revert ClaimUnset();
    }

    function _lzReceive(ILayerZeroEndpointV2.Origin calldata, bytes32, bytes calldata, address, bytes calldata)
        internal
        pure
        override
    {
        revert InboundOnly();
    }
}
