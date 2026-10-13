// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PremarketAddresses} from "./PremarketAddresses.sol";

/// @title PaperOtcFactory
/// @notice Bilateral PAPER escrow. Both sides lock USDM, which this contract wraps to sUSDM.
///         PAPER is pulled only after transfers are enabled, and only for the exact amount.
///         Not a Leaf, not hNEST, not the live PreMarketFactory.
///
///         A covered exit transfers the sUSDM shares that redeem the booked USDM principal.
///         Surplus shares go to `feeRecipient`. This contract never calls sUSDM
///         `withdraw` or `redeem` — Monetrix reverts those (`UseCooldownFunctions`).
///         The recipient unwraps. If a bag cannot cover its principal, the whole
///         remaining share balance is returned. No top-up, and returned shares are
///         not a promise of the same USDM amount.
///
///         Windows are constants (180d cash, 48h delivery). The only delayed parameter is
///         `feeRecipient` (2 days). Non-upgradeable.
contract PaperOtcFactory is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant CASH_WINDOW = 180 days;
    uint256 public constant DELIVERY_WINDOW = 48 hours;
    uint256 public constant FEE_DELAY = 2 days;
    uint256 public constant PAPER_UNIT = 1e18;
    address public constant PAPER = 0xe40f17915DAa230324030003A197cdAEf2261C0e;

    enum State {
        None,
        Open,
        Matched,
        Delivered,
        Settled,
        Defaulted,
        Cancelled,
        Mutual,
        Walked,
        TimedOut
    }

    struct Offer {
        address seller;
        address buyer;
        uint256 paperAmount;
        uint256 priceUsdmPerPaper;
        uint256 sellerPrincipal;
        uint256 buyerPrincipal;
        uint256 sellerShares;
        uint256 buyerShares;
        uint64 matchedAt;
        /// @dev `enabledTime()` when the offer was matched. Delivery spends enabled-time only.
        uint64 deliveryStart;
        State state;
        bool sellerMutual;
        bool buyerMutual;
    }

    IERC20 public immutable usdm;
    IERC4626 public immutable susdm;
    IERC20 public immutable paper;

    address public guardian;
    address public feeRecipient;
    address public pendingFeeRecipient;
    uint64 public feeEta;

    bool public paused;
    bool public paperTransfersEnabled;
    bool public enableProposed;
    /// @dev Guardian-supplied reference. This contract does not replay that transaction.
    bytes32 public transferProofRef;

    /// @dev Enabled-time accrued while transfers were on, excluding the current stretch.
    uint64 public enableCursor;
    uint64 public enableSince;
    /// @dev Increments each time transfers turn on. Once this passes an offer's
    ///      `matchEnableSeq`, that offer's 180-day refund is gone for good.
    uint64 public enableSeq;
    mapping(uint256 => uint64) public matchEnableSeq;

    uint256 public nextId = 1;
    mapping(uint256 => Offer) public offers;

    event OfferCreated(uint256 indexed id, address indexed seller, uint256 paperAmount, uint256 payment, uint256 collateral);
    event OfferTaken(uint256 indexed id, address indexed buyer, uint256 payment);
    event Cancelled(uint256 indexed id);
    event MutualCancelled(uint256 indexed id);
    event SellerWalked(uint256 indexed id);
    event TimedOut(uint256 indexed id);
    event PaperDelivered(uint256 indexed id, uint256 amount);
    event Settled(uint256 indexed id);
    event SellerDefaulted(uint256 indexed id);
    event PrincipalShares(uint256 indexed id, address indexed to, uint256 shares);
    event SharesReturned(uint256 indexed id, address indexed to, uint256 shares);
    event YieldScraped(uint256 indexed id, uint256 shares);
    event TransfersProposed();
    event TransfersEnabled(bytes32 proofRef);
    event TransfersDisabled();
    event Paused();
    event Unpaused();
    event FeeProposed(address indexed next, uint64 eta);
    event FeeUpdated(address indexed feeRecipient);

    error Zero();
    error BadState();
    error NotSeller();
    error NotBuyer();
    error NotParty();
    error NotGuardian();
    error Collateral();
    error Slippage();
    error Window();
    error OffersPaused();
    error Self();
    error Transfers();
    error Proof();
    error Invariant();

    modifier onlyGuardian() {
        if (msg.sender != guardian) revert NotGuardian();
        _;
    }

    constructor(address owner_, address guardian_, address feeRecipient_, address usdm_, address susdm_, address paper_)
        Ownable(owner_)
    {
        if (
            owner_ == address(0) || guardian_ == address(0) || feeRecipient_ == address(0) || usdm_ == address(0)
                || susdm_ == address(0) || paper_ == address(0)
        ) revert Zero();
        if (block.chainid == PremarketAddresses.HYPEREVM) {
            if (usdm_ != PremarketAddresses.USDM || susdm_ != PremarketAddresses.SUSDM || paper_ != PAPER) revert Zero();
        }
        if (IERC4626(susdm_).asset() != usdm_) revert Zero();
        guardian = guardian_;
        feeRecipient = feeRecipient_;
        usdm = IERC20(usdm_);
        susdm = IERC4626(susdm_);
        paper = IERC20(paper_);
    }

    /// @notice USDM the buyer must pay for `paperAmount` at `priceUsdmPerPaper` (USDM per 1 PAPER).
    function paymentOf(uint256 paperAmount, uint256 priceUsdmPerPaper) public pure returns (uint256) {
        if (paperAmount == 0 || priceUsdmPerPaper == 0) revert Zero();
        uint256 payment = Math.mulDiv(paperAmount, priceUsdmPerPaper, PAPER_UNIT);
        if (payment == 0) revert Zero();
        return payment;
    }

    /// @notice True once this offer's 48h delivery cycle has started. Stays true if transfers are later turned off.
    function deliveryCycleStarted(uint256 id) public view returns (bool) {
        if (offers[id].matchedAt == 0) return false;
        return enableSeq > matchEnableSeq[id];
    }

    /// @notice Enabled seconds so far. Frozen while `paperTransfersEnabled` is false.
    function enabledTime() public view returns (uint256) {
        if (!paperTransfersEnabled) return enableCursor;
        return uint256(enableCursor) + (block.timestamp - enableSince);
    }

    function createOffer(uint256 paperAmount, uint256 priceUsdmPerPaper, uint256 collateralUsdm, uint256 maxShares)
        external
        nonReentrant
        returns (uint256 id)
    {
        if (paused) revert OffersPaused();
        uint256 payment = paymentOf(paperAmount, priceUsdmPerPaper);
        if (payment > type(uint256).max / 2) revert Collateral();
        if (collateralUsdm != payment && collateralUsdm != payment * 2) revert Collateral();
        id = nextId++;
        uint256 shares = _wrap(collateralUsdm, maxShares);
        offers[id] = Offer({
            seller: msg.sender,
            buyer: address(0),
            paperAmount: paperAmount,
            priceUsdmPerPaper: priceUsdmPerPaper,
            sellerPrincipal: collateralUsdm,
            buyerPrincipal: 0,
            sellerShares: shares,
            buyerShares: 0,
            matchedAt: 0,
            deliveryStart: 0,
            state: State.Open,
            sellerMutual: false,
            buyerMutual: false
        });
        emit OfferCreated(id, msg.sender, paperAmount, payment, collateralUsdm);
    }

    /// @notice Open offers only. Seller gets sUSDM shares covering principal, or the remaining sUSDM shares.
    function cancelOffer(uint256 id) external nonReentrant {
        Offer storage o = offers[id];
        if (o.state != State.Open) revert BadState();
        if (msg.sender != o.seller) revert NotSeller();
        address to = o.seller;
        uint256 principal = o.sellerPrincipal;
        uint256 shares = o.sellerShares;
        o.state = State.Cancelled;
        o.sellerPrincipal = 0;
        o.sellerShares = 0;
        _payBag(id, to, principal, shares);
        emit Cancelled(id);
    }

    function takeOffer(uint256 id, uint256 maxShares) external nonReentrant {
        if (paused) revert OffersPaused();
        Offer storage o = offers[id];
        if (o.state != State.Open) revert BadState();
        if (msg.sender == o.seller) revert Self();
        uint256 payment = paymentOf(o.paperAmount, o.priceUsdmPerPaper);
        uint256 shares = _wrap(payment, maxShares);
        o.buyer = msg.sender;
        o.buyerPrincipal = payment;
        o.buyerShares = shares;
        o.matchedAt = uint64(block.timestamp);
        o.deliveryStart = uint64(enabledTime());
        // Already on: cycle starts now, so store the previous seq. Still off: store the current seq.
        matchEnableSeq[id] = paperTransfersEnabled ? enableSeq - 1 : enableSeq;
        o.state = State.Matched;
        emit OfferTaken(id, msg.sender, payment);
    }

    /// @notice Both parties, after match, before PAPER is in escrow. Each side is paid its own bag.
    function agreeMutual(uint256 id) external nonReentrant {
        Offer storage o = offers[id];
        if (o.state != State.Matched) revert BadState();
        if (msg.sender == o.seller) o.sellerMutual = true;
        else if (msg.sender == o.buyer) o.buyerMutual = true;
        else revert NotParty();
        if (!o.sellerMutual || !o.buyerMutual) return;
        _cashSplit(id, o.seller, o.buyer, State.Mutual);
        emit MutualCancelled(id);
    }

    /// @notice Seller alone, after match, before PAPER is in escrow. Buyer receives both bags. Seller gets nothing.
    function sellerWalk(uint256 id) external nonReentrant {
        Offer storage o = offers[id];
        if (o.state != State.Matched) revert BadState();
        if (msg.sender != o.seller) revert NotSeller();
        address buyer = o.buyer;
        _cashSplit(id, buyer, buyer, State.Walked);
        emit SellerWalked(id);
    }

    /// @notice Anyone, 180 days after match, and only if this offer's delivery cycle has not started.
    ///         The first time transfers are on after the match, the 180-day refund dies and does not come back.
    function timeoutCash(uint256 id) external nonReentrant {
        Offer storage o = offers[id];
        if (o.state != State.Matched) revert BadState();
        if (deliveryCycleStarted(id)) revert Transfers();
        if (block.timestamp < uint256(o.matchedAt) + CASH_WINDOW) revert Window();
        _cashSplit(id, o.seller, o.buyer, State.TimedOut);
        emit TimedOut(id);
    }

    /// @notice Exact `paperAmount`. Reverts if the token delivers short.
    ///         Allowed after 48h until `finalizeSellerDefault`. If PAPER itself reverts, the offer stays Matched.
    function deliverPaper(uint256 id) external nonReentrant {
        Offer storage o = offers[id];
        if (o.state != State.Matched) revert BadState();
        if (msg.sender != o.seller) revert NotSeller();
        if (!paperTransfersEnabled) revert Transfers();
        uint256 amount = o.paperAmount;
        o.state = State.Delivered;
        uint256 beforeBal = paper.balanceOf(address(this));
        paper.safeTransferFrom(msg.sender, address(this), amount);
        if (paper.balanceOf(address(this)) != beforeBal + amount) revert Invariant();
        emit PaperDelivered(id, amount);
    }

    /// @notice Seller or buyer. No deadline: if PAPER transfers revert, the offer stays Delivered and this can be retried.
    function settlePhysical(uint256 id) external nonReentrant {
        Offer storage o = offers[id];
        if (o.state != State.Delivered) revert BadState();
        if (msg.sender != o.seller && msg.sender != o.buyer) revert NotParty();
        address seller = o.seller;
        address buyer = o.buyer;
        uint256 amount = o.paperAmount;
        _cashSplit(id, seller, seller, State.Settled);
        paper.safeTransfer(buyer, amount);
        emit Settled(id);
    }

    /// @notice Anyone, after 48h of enabled-time with no delivery. Buyer receives both bags. No PAPER moves.
    function finalizeSellerDefault(uint256 id) external nonReentrant {
        Offer storage o = offers[id];
        if (o.state != State.Matched) revert BadState();
        if (!paperTransfersEnabled) revert Transfers();
        if (enabledTime() < uint256(o.deliveryStart) + DELIVERY_WINDOW) revert Window();
        address buyer = o.buyer;
        _cashSplit(id, buyer, buyer, State.Defaulted);
        emit SellerDefaulted(id);
    }

    function proposeEnableTransfers() external onlyOwner {
        if (paperTransfersEnabled) revert Transfers();
        enableProposed = true;
        emit TransfersProposed();
    }

    /// @dev `proofRef` is a tx hash the guardian already checked. It is stored, not verified here.
    function confirmEnableTransfers(bytes32 proofRef) external onlyGuardian {
        if (!enableProposed || paperTransfersEnabled) revert Transfers();
        if (proofRef == bytes32(0)) revert Proof();
        enableProposed = false;
        transferProofRef = proofRef;
        enableSeq += 1;
        paperTransfersEnabled = true;
        enableSince = uint64(block.timestamp);
        emit TransfersEnabled(proofRef);
    }

    function disableTransfers() external onlyGuardian {
        if (!paperTransfersEnabled) revert Transfers();
        enableCursor = uint64(enabledTime());
        enableSince = 0;
        paperTransfersEnabled = false;
        emit TransfersDisabled();
    }

    function pause() external {
        if (msg.sender != owner() && msg.sender != guardian) revert NotGuardian();
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    function proposeFeeRecipient(address next) external onlyOwner {
        if (next == address(0)) revert Zero();
        pendingFeeRecipient = next;
        feeEta = uint64(block.timestamp) + uint64(FEE_DELAY);
        emit FeeProposed(next, feeEta);
    }

    function acceptFeeRecipient() external onlyOwner {
        if (pendingFeeRecipient == address(0) || block.timestamp < feeEta) revert Window();
        feeRecipient = pendingFeeRecipient;
        pendingFeeRecipient = address(0);
        emit FeeUpdated(feeRecipient);
    }

    function _cashSplit(uint256 id, address sellerTo, address buyerTo, State next) internal {
        Offer storage o = offers[id];
        uint256 sp = o.sellerPrincipal;
        uint256 ss = o.sellerShares;
        uint256 bp = o.buyerPrincipal;
        uint256 bs = o.buyerShares;
        o.state = next;
        o.sellerPrincipal = 0;
        o.sellerShares = 0;
        o.buyerPrincipal = 0;
        o.buyerShares = 0;
        _payBag(id, sellerTo, sp, ss);
        _payBag(id, buyerTo, bp, bs);
    }

    /// @dev Shares that cover `principal`, or the whole bag if the quote fails or cannot cover.
    ///      A reverting `convertToAssets` or `previewWithdraw` must not block the exit.
    function _payBag(uint256 id, address to, uint256 principal, uint256 shares) internal {
        if (shares == 0) {
            if (principal == 0) return;
            revert Invariant();
        }
        (bool quoted, uint256 need) = _quotedNeed(principal, shares);
        if (quoted) {
            IERC20(address(susdm)).safeTransfer(to, need);
            emit PrincipalShares(id, to, need);
            if (shares > need) {
                IERC20(address(susdm)).safeTransfer(feeRecipient, shares - need);
                emit YieldScraped(id, shares - need);
            }
            return;
        }
        IERC20(address(susdm)).safeTransfer(to, shares);
        emit SharesReturned(id, to, shares);
    }

    /// @dev False means "do not skim": shortfall, or any quote call reverted. Never reverts on the vault view.
    function _quotedNeed(uint256 principal, uint256 shares) internal view returns (bool ok, uint256 need) {
        if (principal == 0 || shares == 0) return (false, 0);
        (bool coveredOk, uint256 covered) = _staticUint(abi.encodeCall(IERC4626.convertToAssets, (shares)));
        if (!coveredOk || covered < principal) return (false, 0);
        (bool quoteOk, uint256 quoted) = _staticUint(abi.encodeCall(IERC4626.previewWithdraw, (principal)));
        if (!quoteOk || quoted == 0 || quoted > shares) return (false, 0);
        (bool needOk, uint256 needAssets) = _staticUint(abi.encodeCall(IERC4626.convertToAssets, (quoted)));
        if (!needOk) return (false, 0);
        need = quoted;
        if (needAssets < principal) {
            if (need == shares) return (false, 0);
            unchecked {
                need += 1;
            }
            (bool bumpOk, uint256 bumpAssets) = _staticUint(abi.encodeCall(IERC4626.convertToAssets, (need)));
            if (!bumpOk || bumpAssets < principal || need > shares) return (false, 0);
        }
        ok = true;
    }

    function _staticUint(bytes memory data) internal view returns (bool ok, uint256 value) {
        (bool success, bytes memory ret) = address(susdm).staticcall(data);
        if (!success || ret.length < 32) return (false, 0);
        value = abi.decode(ret, (uint256));
        ok = true;
    }

    function _wrap(uint256 assets, uint256 maxShares) internal returns (uint256 shares) {
        usdm.safeTransferFrom(msg.sender, address(this), assets);
        usdm.forceApprove(address(susdm), assets);
        shares = susdm.deposit(assets, address(this));
        if (shares == 0 || shares > maxShares) revert Slippage();
    }
}
