// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {INativeDeliveryResolver} from "./INativeDeliveryResolver.sol";
import {EscrowVault} from "./EscrowVault.sol";

/// @notice Bilateral native-coin OTC. Collateral and payment sit on HyperEVM (USDM→sUSDM).
///         Delivery is attested on the native chain — QTC never enters this contract.
///         Standalone. Do not import from Nest / Gate / Leaf. Do not reuse the VAR factory.
contract NativeOtcFactory is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint64 public constant DELIVERY_WINDOW = 48 hours;

    enum State {
        OPEN,
        TAKEN,
        SETTLED,
        DEFAULTED,
        CANCELLED,
        EXPIRED
    }

    struct Offer {
        address seller;
        address buyer;
        bytes destNative;
        uint256 qtcAtoms;
        uint256 payUsdm;
        uint256 collateralUsdm;
        uint64 createdAt;
        uint64 takenAt;
        uint64 expiry;
        State state;
        bytes32 deliveryTx;
    }

    INativeDeliveryResolver public immutable resolver;
    IERC20 public immutable underlying;
    EscrowVault public immutable vault;
    bytes32 public immutable marketId;

    mapping(bytes32 => Offer) public offers;
    mapping(address => uint256) public sellerNonce;

    event OfferCreated(bytes32 indexed offerId, address seller, uint256 qtcAtoms, uint256 payUsdm, uint256 collateralUsdm);
    event OfferTaken(bytes32 indexed offerId, address buyer, bytes destNative);
    event Settled(bytes32 indexed offerId, bytes32 txHash);
    event Terminal(bytes32 indexed offerId, State state);

    error Unknown();
    error BadState();
    error NotSeller();
    error NotBuyer();
    error Window();
    error Zero();
    error Dest();
    error Amount();
    error Self();

    constructor(address owner_, address resolver_, address feeRecipient_, address share4626) Ownable(owner_) {
        if (owner_ == address(0) || resolver_ == address(0) || feeRecipient_ == address(0) || share4626 == address(0)) {
            revert Zero();
        }
        resolver = INativeDeliveryResolver(resolver_);
        underlying = IERC20(IERC4626(share4626).asset());
        if (address(underlying) == address(0)) revert Zero();
        vault = new EscrowVault(address(this), IERC4626(share4626), feeRecipient_);
        marketId = keccak256(abi.encode("Quantus QTC", share4626, uint256(1)));
    }

    function createOffer(uint256 qtcAtoms, uint256 payUsdm, uint256 collateralUsdm, uint64 ttl, uint256 maxShares)
        external
        nonReentrant
        returns (bytes32 offerId)
    {
        if (qtcAtoms == 0 || payUsdm == 0 || collateralUsdm == 0 || ttl == 0) revert Zero();
        uint256 nonce = ++sellerNonce[msg.sender];
        offerId = keccak256(abi.encode(marketId, msg.sender, nonce, qtcAtoms, payUsdm, collateralUsdm));
        offers[offerId] = Offer({
            seller: msg.sender,
            buyer: address(0),
            destNative: "",
            qtcAtoms: qtcAtoms,
            payUsdm: payUsdm,
            collateralUsdm: collateralUsdm,
            createdAt: uint64(block.timestamp),
            takenAt: 0,
            expiry: uint64(block.timestamp) + ttl,
            state: State.OPEN,
            deliveryTx: bytes32(0)
        });
        _pull(offerId, collateralUsdm, true, maxShares);
        emit OfferCreated(offerId, msg.sender, qtcAtoms, payUsdm, collateralUsdm);
    }

    function cancelOffer(bytes32 offerId) external nonReentrant {
        Offer storage o = offers[offerId];
        if (o.seller == address(0)) revert Unknown();
        if (msg.sender != o.seller) revert NotSeller();
        if (o.state != State.OPEN) revert BadState();
        o.state = State.CANCELLED;
        vault.harvest(offerId);
        vault.release(offerId, o.seller, o.collateralUsdm, true);
        emit Terminal(offerId, State.CANCELLED);
    }

    function expireOffer(bytes32 offerId) external nonReentrant {
        Offer storage o = offers[offerId];
        if (o.seller == address(0)) revert Unknown();
        if (o.state != State.OPEN) revert BadState();
        if (block.timestamp <= o.expiry) revert Window();
        o.state = State.EXPIRED;
        vault.harvest(offerId);
        vault.release(offerId, o.seller, o.collateralUsdm, true);
        emit Terminal(offerId, State.EXPIRED);
    }

    function takeOffer(bytes32 offerId, bytes calldata destNative, uint256 maxShares) external nonReentrant {
        Offer storage o = offers[offerId];
        if (o.seller == address(0)) revert Unknown();
        if (o.state != State.OPEN) revert BadState();
        if (block.timestamp > o.expiry) revert Window();
        if (msg.sender == o.seller) revert Self();
        if (destNative.length == 0) revert Dest();
        o.buyer = msg.sender;
        o.destNative = destNative;
        o.takenAt = uint64(block.timestamp);
        o.state = State.TAKEN;
        _pull(offerId, o.payUsdm, false, maxShares);
        emit OfferTaken(offerId, msg.sender, destNative);
    }

    /// @dev Anyone. Resolver must have attested dest + amount for this offer.
    function settle(bytes32 offerId) external nonReentrant {
        Offer storage o = offers[offerId];
        if (o.state != State.TAKEN) revert BadState();
        (bytes32 txHash, bytes32 destHash, uint256 atoms,, bool ok) = resolver.attestation(offerId);
        if (!ok) revert Amount();
        if (destHash != keccak256(o.destNative)) revert Dest();
        if (atoms < o.qtcAtoms) revert Amount();
        o.deliveryTx = txHash;
        o.state = State.SETTLED;
        vault.harvest(offerId);
        vault.release(offerId, o.seller, o.payUsdm, false);
        vault.release(offerId, o.seller, o.collateralUsdm, true);
        emit Settled(offerId, txHash);
        emit Terminal(offerId, State.SETTLED);
    }

    /// @dev After the 48h window with no matching attestation: buyer takes payment + collateral.
    function finalize(bytes32 offerId) external nonReentrant {
        Offer storage o = offers[offerId];
        if (o.state != State.TAKEN) revert BadState();
        if (block.timestamp <= uint256(o.takenAt) + DELIVERY_WINDOW) revert Window();
        (,,,, bool ok) = resolver.attestation(offerId);
        if (ok) revert BadState();
        o.state = State.DEFAULTED;
        vault.harvest(offerId);
        vault.release(offerId, o.buyer, o.payUsdm, false);
        vault.release(offerId, o.buyer, o.collateralUsdm, true);
        emit Terminal(offerId, State.DEFAULTED);
    }

    function _pull(bytes32 offerId, uint256 assets, bool collateral, uint256 maxShares) internal {
        underlying.safeTransferFrom(msg.sender, address(vault), assets);
        vault.wrapAndCredit(offerId, assets, collateral, maxShares);
    }
}
