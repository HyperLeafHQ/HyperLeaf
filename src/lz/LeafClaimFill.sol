// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LeafClaimPeer} from "./LeafClaimPeer.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";

/// @title LeafClaimFill
/// @notice Source-side inner escrow for a dest `LeafClaimEscrow` order.
///         Buyer deposits exact `wantAmount`. Dest releases Leaf, then ACK
///         pays seller 99% and buyer-reward 1%. REFUND returns inner to buyer.
///         Protocol never takes the inner.
contract LeafClaimFill is LeafClaimPeer, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint16 public constant BPS = 10_000;
    uint16 public constant BUYER_REWARD_BPS = 100;
    uint8 public constant OP_FILL = 1;
    uint8 public constant OP_ACK = 2;
    uint8 public constant OP_REFUND = 3;

    enum FillStatus {
        None,
        Escrowed,
        Paid,
        Refunded
    }

    struct Fill {
        address buyer;
        address seller;
        address wantToken;
        uint128 wantAmount;
        FillStatus status;
    }

    mapping(address wantToken => bool) public allowedInner;
    mapping(uint256 orderId => Fill) public fills;

    event InnerSet(address indexed wantToken, bool allowed);
    event Escrowed(uint256 indexed id, address indexed buyer, uint256 wantAmount);
    event Paid(uint256 indexed id, uint256 toSeller, uint256 buyerReward);
    event Refunded(uint256 indexed id, address indexed buyer, uint256 amount);

    error NotAllowed();
    error BadFill();
    error Busy();

    constructor(address endpoint_, address owner_, address guardian_) LeafClaimPeer(endpoint_, owner_, guardian_) {}

    function setInner(address wantToken, bool allowed) external onlyOwner {
        if (wantToken == address(0)) revert ZeroAddress();
        allowedInner[wantToken] = allowed;
        emit InnerSet(wantToken, allowed);
    }

    /// @notice Lock inner and ask dest to release Leaf. `wantAmount` / `seller`
    ///         must match the dest order or dest refunds.
    function fill(uint256 id, uint32 destEid, address wantToken, uint256 wantAmount, address seller)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (!allowedInner[wantToken]) revert NotAllowed();
        if (wantAmount == 0 || seller == address(0) || seller == msg.sender) revert BadFill();
        if (fills[id].status != FillStatus.None) revert Busy();

        IERC20(wantToken).safeTransferFrom(msg.sender, address(this), wantAmount);
        fills[id] = Fill({
            buyer: msg.sender,
            seller: seller,
            wantToken: wantToken,
            wantAmount: uint128(wantAmount),
            status: FillStatus.Escrowed
        });
        emit Escrowed(id, msg.sender, wantAmount);
        _lzSend(destEid, abi.encode(OP_FILL, id, msg.sender, wantAmount, seller), msg.sender);
    }

    function _lzReceive(ILayerZeroEndpointV2.Origin calldata, bytes32, bytes calldata message, address, bytes calldata)
        internal
        override
    {
        (uint8 op, uint256 id) = abi.decode(message, (uint8, uint256));
        Fill storage f = fills[id];
        if (f.status != FillStatus.Escrowed) revert BadFill();
        if (op == OP_ACK) {
            f.status = FillStatus.Paid;
            (uint256 toSeller, uint256 reward) = _split(f.wantAmount);
            IERC20 token = IERC20(f.wantToken);
            token.safeTransfer(f.seller, toSeller);
            if (reward > 0) token.safeTransfer(f.buyer, reward);
            emit Paid(id, toSeller, reward);
        } else if (op == OP_REFUND) {
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
