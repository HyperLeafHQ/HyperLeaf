// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LeafClaimPeer} from "./LeafClaimPeer.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";

/// @title LeafClaimFill
/// @notice Source-side inner escrow. Inner is paid only after dest ACK, or
///         returned on REFUND / ABORT_OK. Protocol never takes the inner.
///
/// Handshake:
///   fill  → dest FILL → ACK  → pay 99% seller + 1% buyer incentive
///   fill  → dest FILL fail   → REFUND → inner back to buyer
///   abort → dest ABORT → if still Open: ABORT_OK (refund);
///                        if already Filled: ACK (pay seller)
contract LeafClaimFill is LeafClaimPeer, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint16 public constant BPS = 10_000;
    uint16 public constant BUYER_REWARD_BPS = 100;
    uint8 public constant OP_FILL = 1;
    uint8 public constant OP_ACK = 2;
    uint8 public constant OP_REFUND = 3;
    uint8 public constant OP_ABORT = 4;
    uint8 public constant OP_ABORT_OK = 5;
    uint64 public constant ABORT_DELAY = 3 days;

    /// @dev Native dropped with dest lzReceive so dest can send ACK/REFUND without a nested wallet.
    uint128 public returnNative;

    enum FillStatus {
        None,
        Escrowed,
        Aborting,
        Paid,
        Refunded
    }

    struct Fill {
        address buyer;
        address seller;
        address wantToken;
        uint128 wantAmount;
        uint32 destEid;
        uint64 escrowedAt;
        FillStatus status;
    }

    mapping(address wantToken => bool) public allowedInner;
    mapping(uint256 orderId => Fill) public fills;

    event InnerSet(address indexed wantToken, bool allowed);
    event ReturnNativeSet(uint128 value);
    event Escrowed(uint256 indexed id, address indexed buyer, uint256 wantAmount);
    /// @dev User-facing completion for the LZ path. Dest already emitted LeafReleased.
    event Paid(uint256 indexed id, uint256 toSeller, uint256 buyerReward);
    event Refunded(uint256 indexed id, address indexed buyer, uint256 amount);
    event Aborting(uint256 indexed id);

    error NotAllowed();
    error BadFill();
    error Busy();
    error TooEarly();
    error NotBuyer();

    constructor(address endpoint_, address owner_, address guardian_) LeafClaimPeer(endpoint_, owner_, guardian_) {}

    function setInner(address wantToken, bool allowed) external onlyOwner {
        if (wantToken == address(0)) revert ZeroAddress();
        allowedInner[wantToken] = allowed;
        emit InnerSet(wantToken, allowed);
    }

    function setReturnNative(uint128 value) external onlyOwner {
        returnNative = value;
        emit ReturnNativeSet(value);
    }

    function quoteFill(uint256 id, uint32 destEid, address wantToken, uint256 wantAmount, address seller, address buyer)
        external
        view
        returns (uint256 nativeFee)
    {
        bytes memory payload = abi.encode(OP_FILL, id, buyer, wantAmount, seller, wantToken);
        return quote(destEid, payload, _optionsWithValue(returnNative));
    }

    function quoteAbort(uint256 id, uint32 destEid) external view returns (uint256 nativeFee) {
        return quote(destEid, abi.encode(OP_ABORT, id), _optionsWithValue(returnNative));
    }

    function fill(uint256 id, uint32 destEid, address wantToken, uint256 wantAmount, address seller)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (!allowedInner[wantToken]) revert NotAllowed();
        if (wantAmount == 0 || wantAmount > type(uint128).max) revert BadFill();
        if (seller == address(0) || seller == msg.sender) revert BadFill();
        if (fills[id].status != FillStatus.None) revert Busy();
        if (destEid != remoteEid) revert NoPeer();

        IERC20(wantToken).safeTransferFrom(msg.sender, address(this), wantAmount);
        fills[id] = Fill({
            buyer: msg.sender,
            seller: seller,
            wantToken: wantToken,
            wantAmount: uint128(wantAmount),
            destEid: destEid,
            escrowedAt: uint64(block.timestamp),
            status: FillStatus.Escrowed
        });
        emit Escrowed(id, msg.sender, wantAmount);
        _lzSend(destEid, abi.encode(OP_FILL, id, msg.sender, wantAmount, seller, wantToken), _optionsWithValue(returnNative), msg.sender);
    }

    /// @notice Buyer after `ABORT_DELAY`, or guardian/owner now. Dest decides:
    ///         still Open → ABORT_OK (refund); already Filled → ACK (pay).
    function abortFill(uint256 id) external payable nonReentrant {
        Fill storage f = fills[id];
        if (f.status != FillStatus.Escrowed) revert BadFill();
        bool privileged = msg.sender == owner() || msg.sender == guardian;
        if (!privileged) {
            if (msg.sender != f.buyer) revert NotBuyer();
            if (block.timestamp < uint256(f.escrowedAt) + ABORT_DELAY) revert TooEarly();
        }
        f.status = FillStatus.Aborting;
        emit Aborting(id);
        _lzSend(f.destEid, abi.encode(OP_ABORT, id), _optionsWithValue(returnNative), msg.sender);
    }

    function retryAbort(uint256 id) external payable nonReentrant {
        Fill storage f = fills[id];
        if (f.status != FillStatus.Aborting) revert BadFill();
        _lzSend(f.destEid, abi.encode(OP_ABORT, id), _optionsWithValue(returnNative), msg.sender);
    }

    function _lzReceive(ILayerZeroEndpointV2.Origin calldata origin, bytes32, bytes calldata message, address, bytes calldata)
        internal
        override
    {
        (uint8 op, uint256 id) = abi.decode(message, (uint8, uint256));
        Fill storage f = fills[id];
        if (f.destEid == 0 || origin.srcEid != f.destEid) return;
        if (op == OP_ACK) {
            if (f.status != FillStatus.Escrowed && f.status != FillStatus.Aborting) return;
            f.status = FillStatus.Paid;
            (uint256 toSeller, uint256 reward) = _split(f.wantAmount);
            IERC20 token = IERC20(f.wantToken);
            token.safeTransfer(f.seller, toSeller);
            if (reward > 0) token.safeTransfer(f.buyer, reward);
            emit Paid(id, toSeller, reward);
        } else if (op == OP_REFUND || op == OP_ABORT_OK) {
            if (f.status != FillStatus.Escrowed && f.status != FillStatus.Aborting) return;
            f.status = FillStatus.Refunded;
            IERC20(f.wantToken).safeTransfer(f.buyer, f.wantAmount);
            emit Refunded(id, f.buyer, f.wantAmount);
        } else {
            revert BadFill();
        }
    }

    function _split(uint256 wantAmount) internal pure returns (uint256 toSeller, uint256 reward) {
        reward = (wantAmount * BUYER_REWARD_BPS) / BPS;
        toSeller = wantAmount - reward;
    }
}
