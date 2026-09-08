// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LeafClaimPeer} from "./LeafClaimPeer.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";

interface IClaimHype {
    function claim(bytes32 id, address to) external;
    function pending(bytes32 id, address user) external view returns (uint256);
}

/// @title LeafClaimEscrow
/// @notice Exit board. Protocol is never the counterparty. No mint. Execution
///         fee is 0. 1% of ask is a **buyer incentive**. Occupancy HYPE while
///         listed → `feeRecipient` **only if** this listing's Rewarder is set.
///         hNEST has no Rewarder; do not invent occupancy HYPE for it.
///
/// Settlement events (do not treat dest `Status.Filled` as cash settled):
///   `fillLocal` — atomic. Emits `Filled` = Leaf + 99/1 want moved.
///   cross-chain — dest emits `LeafReleased` when the Leaf leaves escrow.
///                 source emits `Paid` when 99% seller / 1% buyer actually move.
///                 UI completion signal is `Paid`, not dest `Filled`.
/// Ask is frozen at `list`. Expiry ≤ 90 days. No matching engine.
///
/// Allowlist (owner `setMarket`):
/// 1. **C1 Closed OFTs first** — no protocol redeem; this is the product.
/// 2. **hNEST / same-chain window receipts** — `fillLocal` (NEST and hNEST
///    both live on HyperEVM). No NestVault fork.
/// 3. **Share-price Liquid** — same contracts, no extra yield split. NAV
///    stays in the token; cancel may earn the seller the appreciation and
///    protocol 0. Owner may allowlist later; do not build a second accounting
///    model for it.
contract LeafClaimEscrow is LeafClaimPeer, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint16 public constant BPS = 10_000;
    uint16 public constant BUYER_REWARD_BPS = 100; // 1% of ask → buyer incentive, not a protocol fee
    uint64 public constant MAX_TTL = 90 days;
    uint8 public constant OP_FILL = 1;
    uint8 public constant OP_ACK = 2;
    uint8 public constant OP_REFUND = 3;
    uint8 public constant OP_ABORT = 4;
    uint8 public constant OP_ABORT_OK = 5;

    address public feeRecipient;
    IClaimHype public rewarder;

    enum Status {
        None,
        Open,
        Filled,
        Cancelled,
        Expired
    }

    struct Order {
        address seller;
        address sourceRecipient;
        address leaf;
        address wantToken;
        uint128 leafAmount;
        uint128 wantAmount;
        uint64 expiry;
        Status status;
    }

    struct Market {
        bool allowed;
        bytes32 rewardId;
    }

    uint256 public nextId = 1;
    mapping(uint256 id => Order) public orders;
    /// @dev leaf → wantToken (source inner address) → market
    mapping(address leaf => mapping(address wantToken => Market)) public markets;
    mapping(uint256 id => bool) public aborted;
    mapping(uint256 id => uint32) public fillSrcEid;

    event MarketSet(address indexed leaf, address indexed wantToken, bytes32 rewardId, bool allowed);
    event Listed(uint256 indexed id, address indexed seller, address leaf, uint256 leafAmount, address wantToken, uint256 wantAmount, uint64 expiry);
    event Cancelled(uint256 indexed id);
    event Expired(uint256 indexed id);
    event Filled(uint256 indexed id, address indexed buyer, uint256 toSeller, uint256 buyerReward);
    /// @dev Dest Leaf left escrow. Source `Paid` is still pending on LZ.
    event LeafReleased(uint256 indexed id, address indexed buyer, uint256 leafAmount);
    event OccupancyClaimed(bytes32 indexed rewardId, uint256 amount);
    event Aborted(uint256 indexed id);
    event AckRetried(uint256 indexed id);
    event RefundRetried(uint256 indexed id);

    error NotAllowed();
    error BadOrder();
    error NotSeller();
    error NotOpen();
    error NotExpired();
    error SameParty();

    constructor(address endpoint_, address owner_, address guardian_, address feeRecipient_)
        LeafClaimPeer(endpoint_, owner_, guardian_)
    {
        if (feeRecipient_ == address(0)) revert ZeroAddress();
        feeRecipient = feeRecipient_;
    }

    function setFeeRecipient(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        feeRecipient = to;
    }

    function setRewarder(address r) external onlyOwner {
        rewarder = IClaimHype(r);
    }

    /// @notice Allowlist a Leaf against the inner used as ask.
    ///         C1 first. hNEST: same-chain `wantToken` = NEST. Share-price: only
    ///         if you accept occupancy = 0 on cancel.
    function setMarket(address leaf, address wantToken, bytes32 rewardId, bool allowed) external onlyOwner {
        if (leaf == address(0) || wantToken == address(0)) revert ZeroAddress();
        markets[leaf][wantToken] = Market(allowed, rewardId);
        emit MarketSet(leaf, wantToken, rewardId, allowed);
    }

    function list(
        address leaf,
        uint256 leafAmount,
        address wantToken,
        uint256 wantAmount,
        address sourceRecipient,
        uint64 expiry
    ) external whenNotPaused nonReentrant returns (uint256 id) {
        Market memory m = markets[leaf][wantToken];
        if (!m.allowed) revert NotAllowed();
        if (leafAmount == 0 || wantAmount == 0) revert BadOrder();
        if (leafAmount > type(uint128).max || wantAmount > type(uint128).max) revert BadOrder();
        if (sourceRecipient == address(0)) revert ZeroAddress();
        if (expiry <= block.timestamp || expiry > block.timestamp + MAX_TTL) revert BadOrder();

        IERC20(leaf).safeTransferFrom(msg.sender, address(this), leafAmount);
        id = nextId++;
        orders[id] = Order({
            seller: msg.sender,
            sourceRecipient: sourceRecipient,
            leaf: leaf,
            wantToken: wantToken,
            leafAmount: uint128(leafAmount),
            wantAmount: uint128(wantAmount),
            expiry: expiry,
            status: Status.Open
        });
        emit Listed(id, msg.sender, leaf, leafAmount, wantToken, wantAmount, expiry);
    }

    /// @notice Seller rescue. No cancel fee. In-flight FILL sees NotOpen and refunds.
    function cancel(uint256 id, uint32 srcEid) external payable nonReentrant {
        Order storage o = orders[id];
        if (o.seller != msg.sender) revert NotSeller();
        if (o.status != Status.Open) revert NotOpen();
        o.status = Status.Cancelled;
        IERC20(o.leaf).safeTransfer(o.seller, o.leafAmount);
        emit Cancelled(id);
        if (srcEid != 0 && peers[srcEid] != bytes32(0) && msg.value > 0) {
            _lzSend(srcEid, abi.encode(OP_REFUND, id), msg.sender);
        }
    }

    function expire(uint256 id, uint32 srcEid) external payable nonReentrant {
        Order storage o = orders[id];
        if (o.status != Status.Open) revert NotOpen();
        if (block.timestamp < o.expiry) revert NotExpired();
        o.status = Status.Expired;
        IERC20(o.leaf).safeTransfer(o.seller, o.leafAmount);
        emit Expired(id);
        if (srcEid != 0 && peers[srcEid] != bytes32(0) && msg.value > 0) {
            _lzSend(srcEid, abi.encode(OP_REFUND, id), msg.sender);
        }
    }

    /// @notice Same-chain settlement (tests / inner already on dest). Atomic.
    function fillLocal(uint256 id) external whenNotPaused nonReentrant {
        Order storage o = orders[id];
        if (o.status != Status.Open) revert NotOpen();
        if (block.timestamp >= o.expiry) revert NotExpired();
        if (msg.sender == o.seller) revert SameParty();
        _payoutLeaf(o, msg.sender);
        (uint256 toSeller, uint256 reward) = _split(o.wantAmount);
        IERC20 want = IERC20(o.wantToken);
        want.safeTransferFrom(msg.sender, address(this), o.wantAmount);
        want.safeTransfer(o.sourceRecipient, toSeller);
        if (reward > 0) want.safeTransfer(msg.sender, reward);
        emit Filled(id, msg.sender, toSeller, reward);
    }

    /// @notice Resend ACK if dest filled but source never got paid.
    function retryAck(uint256 id) external payable nonReentrant {
        Order storage o = orders[id];
        if (o.status != Status.Filled) revert NotOpen();
        uint32 srcEid = fillSrcEid[id];
        if (srcEid == 0) revert BadOrder();
        _lzSend(srcEid, abi.encode(OP_ACK, id), msg.sender);
        emit AckRetried(id);
    }

    /// @notice Resend REFUND. Anyone may pay LZ. Uses the frozen source peer if
    ///         dest never saw the FILL (`cancel` without gas).
    function retryRefund(uint256 id) external payable nonReentrant {
        Order storage o = orders[id];
        uint32 srcEid = fillSrcEid[id] != 0 ? fillSrcEid[id] : remoteEid;
        if (srcEid == 0) revert BadOrder();
        if (o.status == Status.Filled) revert NotOpen();
        _lzSend(srcEid, abi.encode(OP_REFUND, id), msg.sender);
        emit RefundRetried(id);
    }
    /// @notice Occupancy HYPE while this contract holds Leaf. Permissionless.
    function claimOccupancy(bytes32 rewardId) external nonReentrant {
        if (address(rewarder) == address(0) || rewardId == bytes32(0)) revert BadOrder();
        uint256 before = _pending(rewardId);
        rewarder.claim(rewardId, feeRecipient);
        emit OccupancyClaimed(rewardId, before);
    }

    function _lzReceive(ILayerZeroEndpointV2.Origin calldata origin, bytes32, bytes calldata message, address, bytes calldata)
        internal
        override
        whenNotPaused
    {
        (uint8 op, uint256 id) = abi.decode(message, (uint8, uint256));
        fillSrcEid[id] = origin.srcEid;
        if (op == OP_ABORT) {
            aborted[id] = true;
            emit Aborted(id);
            if (orders[id].status == Status.Filled) {
                _lzSend(origin.srcEid, abi.encode(OP_ACK, id), address(this));
            } else {
                _lzSend(origin.srcEid, abi.encode(OP_ABORT_OK, id), address(this));
            }
            return;
        }
        if (op != OP_FILL) revert BadOrder();
        (, , address buyer, uint256 wantAmount, address payout, address wantToken) =
            abi.decode(message, (uint8, uint256, address, uint256, address, address));
        Order storage o = orders[id];
        if (
            aborted[id] || o.status != Status.Open || block.timestamp >= o.expiry || buyer == address(0)
                || buyer == o.seller || wantAmount != o.wantAmount || payout != o.sourceRecipient
                || wantToken != o.wantToken
        ) {
            _lzSend(origin.srcEid, abi.encode(OP_REFUND, id), address(this));
            return;
        }
        _payoutLeaf(o, buyer);
        emit LeafReleased(id, buyer, o.leafAmount);
        _lzSend(origin.srcEid, abi.encode(OP_ACK, id), address(this));
    }

    function _payoutLeaf(Order storage o, address buyer) private {
        o.status = Status.Filled;
        IERC20(o.leaf).safeTransfer(buyer, o.leafAmount);
    }

    function _split(uint256 wantAmount) internal pure returns (uint256 toSeller, uint256 reward) {
        reward = (wantAmount * BUYER_REWARD_BPS) / BPS;
        toSeller = wantAmount - reward;
    }

    function _pending(bytes32 rewardId) private view returns (uint256) {
        return rewarder.pending(rewardId, address(this));
    }

    function split(uint256 wantAmount) external pure returns (uint256 toSeller, uint256 reward) {
        return _split(wantAmount);
    }
}
