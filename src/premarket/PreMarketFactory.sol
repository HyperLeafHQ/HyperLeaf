// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IConversionResolver} from "./IConversionResolver.sol";
import {ClaimSeriesToken} from "./ClaimSeriesToken.sol";
import {EscrowVault} from "./EscrowVault.sol";

/// @notice Pre-TGE bilateral-escrow claim factory. Standalone. Core must not import this.
contract PreMarketFactory {
    using SafeERC20 for IERC20;

    uint64 public constant DELIVERY_WINDOW = 48 hours;
    uint64 public constant EXPIRY = 365 days;
    uint64 public constant RESOLVE_GRACE = 48 hours;
    uint256 public constant BPS = 10_000;
    uint256 public constant MIN_REFERENCE_PRICE_USD = 1e18;
    uint8 public constant MIN_COLLATERAL_DECIMALS = 6;
    uint8 public constant MAX_COLLATERAL_DECIMALS = 18;

    enum State {
        OPEN,
        RESOLVED,
        SETTLED,
        DEFAULTED,
        EXPIRED,
        VOIDED,
        CLOSED
    }

    struct Market {
        address asset;
        uint8 assetDecimals;
        string name;
        string symbolBase;
        bool live;
    }

    struct Series {
        bytes32 marketId;
        address seller;
        address claimToken;
        uint16 tierBps;
        uint256 refPriceUsd;
        uint256 unitRequirement;
        uint64 createdAt;
        State state;
        uint256 soldSupply;
        uint256 finalSoldSupply;
        uint256 finalEscrowPool;
        uint256 finalCollateralPool;
        address officialToken;
        uint256 rateX18;
        uint64 marketResolvedAt;
        uint64 seriesResolvedAt;
        uint256 delivered;
        uint8 officialDecimals;
        bool snapshotted;
    }

    IConversionResolver public immutable resolver;
    address public owner;
    address public lockbox;
    address public feeRecipient;

    mapping(bytes32 => Market) public markets;
    mapping(bytes32 => Series) public seriesOf;
    mapping(bytes32 => EscrowVault) public vaultOf;
    mapping(bytes32 => uint256) public sellerClaimableC;
    mapping(bytes32 => uint256) public sellerClaimableR;
    mapping(bytes32 => uint256) public paidOut;
    uint256 public marketsCreated;
    mapping(address => uint256) public sellerNonce;

    event MarketCreated(bytes32 indexed marketId, address asset, string name);
    event SeriesCreated(bytes32 indexed seriesId, bytes32 marketId, address seller, address claimToken);
    event Minted(bytes32 indexed seriesId, uint256 claims);
    event PrimaryFill(bytes32 indexed seriesId, address buyer, uint256 claims, uint256 paid);
    event ResolvedSeries(bytes32 indexed seriesId, address token, uint256 rateX18);
    event Delivered(bytes32 indexed seriesId, uint256 amount, uint256 cumulative);
    event Terminal(bytes32 indexed seriesId, State state, uint256 sold, uint256 escrow, uint256 collateral);
    event SettledHolder(bytes32 indexed seriesId, address holder, uint256 claims);

    error NotOwner();
    error NotSeller();
    error BadState();
    error BadTier();
    error BadAsset();
    error Floor();
    error Unknown();
    error Window();
    error NotResolved();
    error Zero();
    error Cap();
    error NotLockbox();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address owner_, address resolver_, address feeRecipient_) {
        owner = owner_;
        resolver = IConversionResolver(resolver_);
        feeRecipient = feeRecipient_;
    }

    function setLockbox(address l) external onlyOwner {
        lockbox = l;
    }

    function officialTokenOf(bytes32 seriesId) external view returns (address) {
        return seriesOf[seriesId].officialToken;
    }

    function seriesState(bytes32 seriesId) external view returns (State) {
        return seriesOf[seriesId].state;
    }

    function seriesClaim(bytes32 seriesId) external view returns (address) {
        return seriesOf[seriesId].claimToken;
    }

    function seriesUnit(bytes32 seriesId) external view returns (uint256) {
        return seriesOf[seriesId].unitRequirement;
    }

    function seriesFinalSold(bytes32 seriesId) external view returns (uint256) {
        return seriesOf[seriesId].finalSoldSupply;
    }

    function createMarket(string calldata name, string calldata symbolBase, address asset)
        external
        onlyOwner
        returns (bytes32 marketId)
    {
        uint8 dec = IERC20Metadata(asset).decimals();
        if (dec < MIN_COLLATERAL_DECIMALS || dec > MAX_COLLATERAL_DECIMALS) revert BadAsset();
        marketId = keccak256(abi.encode(name, asset, ++marketsCreated));
        markets[marketId] = Market(asset, dec, name, symbolBase, true);
        vaultOf[marketId] = new EscrowVault(address(this), IERC20(asset), feeRecipient);
        emit MarketCreated(marketId, asset, name);
    }

    /// @dev 1x = seller-friendly listing. 2x = HyperLeaf guarantee. No 3x.
    function createSeries(bytes32 marketId, uint16 tierBps, uint256 refPriceUsd)
        external
        returns (bytes32 seriesId)
    {
        Market storage m = markets[marketId];
        if (!m.live) revert Unknown();
        if (tierBps != 10_000 && tierBps != 20_000) revert BadTier();
        if (refPriceUsd < MIN_REFERENCE_PRICE_USD) revert Floor();
        uint256 unit = _unitRequirement(refPriceUsd, tierBps, m.assetDecimals);
        if (unit < 10 ** m.assetDecimals) revert Floor();
        uint256 nonce = ++sellerNonce[msg.sender];
        seriesId = keccak256(abi.encode(marketId, tierBps, refPriceUsd, msg.sender, nonce));
        address clone = address(new ClaimSeriesToken());
        string memory sym = _ticker(m.symbolBase, refPriceUsd, tierBps);
        ClaimSeriesToken(clone).initialize(address(this), m.name, sym);
        seriesOf[seriesId] = Series({
            marketId: marketId,
            seller: msg.sender,
            claimToken: clone,
            tierBps: tierBps,
            refPriceUsd: refPriceUsd,
            unitRequirement: unit,
            createdAt: 0,
            state: State.OPEN,
            soldSupply: 0,
            finalSoldSupply: 0,
            finalEscrowPool: 0,
            finalCollateralPool: 0,
            officialToken: address(0),
            rateX18: 0,
            marketResolvedAt: 0,
            seriesResolvedAt: 0,
            delivered: 0,
            officialDecimals: 18,
            snapshotted: false
        });
        emit SeriesCreated(seriesId, marketId, msg.sender, clone);
    }

    function depositAndMint(bytes32 seriesId, uint256 claimAmount) external {
        Series storage s = _openSeller(seriesId);
        if (claimAmount == 0) revert Zero();
        if (s.createdAt == 0) s.createdAt = uint64(block.timestamp);
        uint256 col = Math.mulDiv(claimAmount, s.unitRequirement, 1e18, Math.Rounding.Ceil);
        IERC20(markets[s.marketId].asset).safeTransferFrom(msg.sender, address(vaultOf[s.marketId]), col);
        vaultOf[s.marketId].credit(seriesId, col, true);
        ClaimSeriesToken(s.claimToken).mint(address(this), claimAmount);
        emit Minted(seriesId, claimAmount);
    }

    function buyFromSeries(bytes32 seriesId, uint256 amount) external {
        Series storage s = seriesOf[seriesId];
        if (s.claimToken == address(0)) revert Unknown();
        if (s.state != State.OPEN) revert BadState();
        if (amount == 0) revert Zero();
        ClaimSeriesToken t = ClaimSeriesToken(s.claimToken);
        if (t.balanceOf(address(this)) < amount) revert Cap();
        uint256 price = _priceAtoms(s);
        uint256 paid = Math.mulDiv(amount, price, 1e18, Math.Rounding.Ceil);
        IERC20(markets[s.marketId].asset).safeTransferFrom(msg.sender, address(vaultOf[s.marketId]), paid);
        vaultOf[s.marketId].credit(seriesId, paid, false);
        s.soldSupply += amount;
        require(t.transfer(msg.sender, amount), "xfer");
        emit PrimaryFill(seriesId, msg.sender, amount, paid);
    }

    function burnClaims(bytes32 seriesId, uint256 amount) external {
        Series storage s = seriesOf[seriesId];
        if (s.state != State.OPEN && s.state != State.RESOLVED) revert BadState();
        ClaimSeriesToken(s.claimToken).burn(msg.sender, amount);
        if (s.soldSupply >= amount) s.soldSupply -= amount;
        else s.soldSupply = 0;
    }

    function burnUnsoldAndWithdrawExcess(bytes32 seriesId) external {
        Series storage s = _openOrResolvedSeller(seriesId);
        ClaimSeriesToken t = ClaimSeriesToken(s.claimToken);
        uint256 inv = t.balanceOf(address(this));
        if (inv > 0) t.burn(address(this), inv);
        uint256 need = Math.mulDiv(t.totalSupply(), s.unitRequirement, 1e18, Math.Rounding.Ceil);
        uint256 have = vaultOf[s.marketId].collateralOf(seriesId);
        if (have > need) {
            vaultOf[s.marketId].release(seriesId, s.seller, have - need, true);
        }
    }

    function resolve(bytes32 seriesId) external {
        Series storage s = seriesOf[seriesId];
        if (s.state != State.OPEN) revert BadState();
        if (s.createdAt == 0) revert BadState();
        (address tok, uint256 rate, uint64 at, bool ok) = resolver.resolution(s.marketId);
        if (!ok) revert NotResolved();
        uint64 deadline = s.createdAt + EXPIRY;
        if (block.timestamp > deadline + RESOLVE_GRACE) revert Window();
        if (block.timestamp > deadline && at > deadline) revert Window();
        s.officialToken = tok;
        s.rateX18 = rate;
        s.marketResolvedAt = at;
        s.seriesResolvedAt = uint64(block.timestamp);
        s.officialDecimals = IERC20Metadata(tok).decimals();
        s.state = State.RESOLVED;
        uint256 inv = ClaimSeriesToken(s.claimToken).balanceOf(address(this));
        if (inv > 0) ClaimSeriesToken(s.claimToken).burn(address(this), inv);
        uint256 need = Math.mulDiv(ClaimSeriesToken(s.claimToken).totalSupply(), s.unitRequirement, 1e18, Math.Rounding.Ceil);
        uint256 have = vaultOf[s.marketId].collateralOf(seriesId);
        if (have > need) vaultOf[s.marketId].release(seriesId, s.seller, have - need, true);
        emit ResolvedSeries(seriesId, tok, rate);
    }

    function deliver(bytes32 seriesId, uint256 amount) external {
        Series storage s = seriesOf[seriesId];
        if (s.state != State.RESOLVED) revert BadState();
        if (msg.sender != s.seller) revert NotSeller();
        if (block.timestamp > s.seriesResolvedAt + DELIVERY_WINDOW) revert Window();
        if (amount == 0) revert Zero();
        IERC20(s.officialToken).safeTransferFrom(msg.sender, address(this), amount);
        _credit(seriesId, amount);
    }

    function onDeliveryCredit(bytes32 seriesId, uint256 amount) external {
        if (msg.sender != lockbox) revert NotLockbox();
        Series storage s = seriesOf[seriesId];
        if (s.state != State.RESOLVED) revert BadState();
        if (block.timestamp > s.seriesResolvedAt + DELIVERY_WINDOW) revert Window();
        _credit(seriesId, amount);
    }

    function finalize(bytes32 seriesId) external {
        Series storage s = seriesOf[seriesId];
        if (s.state != State.RESOLVED) revert BadState();
        if (block.timestamp <= s.seriesResolvedAt + DELIVERY_WINDOW) revert Window();
        uint256 req = _required(s);
        if (s.delivered >= req) _toSettled(seriesId);
        else _toDefaulted(seriesId);
    }

    function expire(bytes32 seriesId) external {
        Series storage s = seriesOf[seriesId];
        if (s.state != State.OPEN) revert BadState();
        if (s.createdAt == 0) revert BadState();
        uint64 deadline = s.createdAt + EXPIRY;
        if (block.timestamp <= deadline) revert Window();
        (,,, bool resolved) = resolver.resolution(s.marketId);
        uint64 at;
        if (resolved) {
            (, , at,) = resolver.resolution(s.marketId);
            if (at <= deadline && block.timestamp <= deadline + RESOLVE_GRACE) revert Window();
        }
        _toRefundBoth(seriesId, State.EXPIRED);
    }

    function voidSeries(bytes32 seriesId) external {
        Series storage s = seriesOf[seriesId];
        if (s.state != State.OPEN) revert BadState();
        if (!resolver.voided(s.marketId)) revert NotResolved();
        _toRefundBoth(seriesId, State.VOIDED);
    }

    function closeSeries(bytes32 seriesId) external {
        Series storage s = _openOrResolvedSeller(seriesId);
        if (ClaimSeriesToken(s.claimToken).totalSupply() != 0) revert Cap();
        if (s.delivered != 0) revert Cap();
        vaultOf[s.marketId].harvest(seriesId);
        uint256 c = vaultOf[s.marketId].collateralOf(seriesId);
        uint256 r = vaultOf[s.marketId].escrowOf(seriesId);
        if (c > 0) vaultOf[s.marketId].release(seriesId, s.seller, c, true);
        if (r > 0) vaultOf[s.marketId].release(seriesId, s.seller, r, false);
        s.state = State.CLOSED;
        emit Terminal(seriesId, State.CLOSED, 0, 0, 0);
    }

    function harvest(bytes32 seriesId) external {
        Series storage s = seriesOf[seriesId];
        vaultOf[s.marketId].harvest(seriesId);
    }

    function redeemPull(bytes32 seriesId) external {
        _settle(seriesId, msg.sender);
    }

    function pushSettle(bytes32 seriesId, address holder) external {
        _settle(seriesId, holder);
    }

    function withdrawSettlement(bytes32 seriesId) external {
        Series storage s = seriesOf[seriesId];
        if (msg.sender != s.seller) revert NotSeller();
        if (s.state != State.SETTLED && s.state != State.EXPIRED && s.state != State.VOIDED && s.state != State.CLOSED) {
            revert BadState();
        }
        uint256 c = sellerClaimableC[seriesId];
        uint256 r = sellerClaimableR[seriesId];
        sellerClaimableC[seriesId] = 0;
        sellerClaimableR[seriesId] = 0;
        if (c > 0) vaultOf[s.marketId].release(seriesId, s.seller, c, true);
        if (r > 0) vaultOf[s.marketId].release(seriesId, s.seller, r, false);
    }

    function reclaimPartialDelivery(bytes32 seriesId) external {
        Series storage s = seriesOf[seriesId];
        if (msg.sender != s.seller) revert NotSeller();
        if (s.state != State.DEFAULTED && !(s.state == State.SETTLED && s.finalSoldSupply == 0)) revert BadState();
        uint256 amt = s.delivered;
        s.delivered = 0;
        if (amt > 0) IERC20(s.officialToken).safeTransfer(s.seller, amt);
    }

    function _credit(bytes32 seriesId, uint256 amount) internal {
        Series storage s = seriesOf[seriesId];
        s.delivered += amount;
        emit Delivered(seriesId, amount, s.delivered);
        if (s.delivered >= _required(s)) _toSettled(seriesId);
    }

    function _toSettled(bytes32 seriesId) internal {
        Series storage s = seriesOf[seriesId];
        _burnIneligible(seriesId);
        vaultOf[s.marketId].harvest(seriesId);
        _releaseExcess(seriesId);
        s.finalSoldSupply = ClaimSeriesToken(s.claimToken).totalSupply();
        s.finalEscrowPool = 0;
        s.finalCollateralPool = 0;
        s.snapshotted = true;
        s.state = State.SETTLED;
        sellerClaimableC[seriesId] = vaultOf[s.marketId].collateralOf(seriesId);
        sellerClaimableR[seriesId] = vaultOf[s.marketId].escrowOf(seriesId);
        emit Terminal(seriesId, State.SETTLED, s.finalSoldSupply, sellerClaimableR[seriesId], sellerClaimableC[seriesId]);
    }

    function _toDefaulted(bytes32 seriesId) internal {
        Series storage s = seriesOf[seriesId];
        _burnIneligible(seriesId);
        vaultOf[s.marketId].harvest(seriesId);
        _releaseExcess(seriesId);
        uint256 sold = ClaimSeriesToken(s.claimToken).totalSupply();
        s.finalSoldSupply = sold;
        s.finalEscrowPool = vaultOf[s.marketId].escrowOf(seriesId);
        uint256 capC = Math.mulDiv(sold, s.unitRequirement, 1e18, Math.Rounding.Ceil);
        uint256 have = vaultOf[s.marketId].collateralOf(seriesId);
        if (have > capC) {
            vaultOf[s.marketId].release(seriesId, s.seller, have - capC, true);
            have = capC;
        }
        s.finalCollateralPool = have;
        s.snapshotted = true;
        s.state = State.DEFAULTED;
        emit Terminal(seriesId, State.DEFAULTED, sold, s.finalEscrowPool, s.finalCollateralPool);
    }

    function _toRefundBoth(bytes32 seriesId, State st) internal {
        Series storage s = seriesOf[seriesId];
        _burnIneligible(seriesId);
        vaultOf[s.marketId].harvest(seriesId);
        uint256 sold = ClaimSeriesToken(s.claimToken).totalSupply();
        s.finalSoldSupply = sold;
        s.finalEscrowPool = vaultOf[s.marketId].escrowOf(seriesId);
        s.finalCollateralPool = 0;
        s.snapshotted = true;
        s.state = st;
        sellerClaimableC[seriesId] = vaultOf[s.marketId].collateralOf(seriesId);
        if (sold == 0) {
            sellerClaimableR[seriesId] = s.finalEscrowPool;
            s.finalEscrowPool = 0;
        }
        emit Terminal(seriesId, st, sold, s.finalEscrowPool, sellerClaimableC[seriesId]);
    }

    /// @dev P1: factory inventory and seller-held claims are unsold, not terminal payouts.
    function _burnIneligible(bytes32 seriesId) internal {
        Series storage s = seriesOf[seriesId];
        ClaimSeriesToken t = ClaimSeriesToken(s.claimToken);
        uint256 inv = t.balanceOf(address(this));
        if (inv > 0) t.burn(address(this), inv);
        uint256 held = t.balanceOf(s.seller);
        if (held > 0) t.burn(s.seller, held);
    }

    function _releaseExcess(bytes32 seriesId) internal {
        Series storage s = seriesOf[seriesId];
        uint256 need = Math.mulDiv(ClaimSeriesToken(s.claimToken).totalSupply(), s.unitRequirement, 1e18, Math.Rounding.Ceil);
        uint256 have = vaultOf[s.marketId].collateralOf(seriesId);
        if (have > need) vaultOf[s.marketId].release(seriesId, s.seller, have - need, true);
    }

    function _settle(bytes32 seriesId, address holder) internal {
        Series storage s = seriesOf[seriesId];
        if (!s.snapshotted) revert BadState();
        ClaimSeriesToken t = ClaimSeriesToken(s.claimToken);
        uint256 amt = t.balanceOf(holder);
        if (amt == 0) revert Zero();
        t.burn(holder, amt);
        if (s.state == State.SETTLED) {
            uint256 tokens = Math.mulDiv(amt, s.rateX18, 1e18);
            if (s.officialDecimals < 18) tokens = tokens / (10 ** (18 - s.officialDecimals));
            else if (s.officialDecimals > 18) tokens = tokens * (10 ** (s.officialDecimals - 18));
            IERC20(s.officialToken).safeTransfer(holder, tokens);
        } else if (s.state == State.DEFAULTED) {
            uint256 sold = s.finalSoldSupply;
            uint256 rPay = Math.mulDiv(amt, s.finalEscrowPool, sold);
            uint256 cPay = Math.mulDiv(amt, s.finalCollateralPool, sold);
            paidOut[seriesId] += rPay + cPay;
            vaultOf[s.marketId].release(seriesId, holder, rPay, false);
            vaultOf[s.marketId].release(seriesId, holder, cPay, true);
        } else if (s.state == State.EXPIRED || s.state == State.VOIDED) {
            uint256 cash = Math.mulDiv(amt, s.finalEscrowPool, s.finalSoldSupply);
            vaultOf[s.marketId].release(seriesId, holder, cash, false);
        } else {
            revert BadState();
        }
        emit SettledHolder(seriesId, holder, amt);
    }

    function _required(Series storage s) internal view returns (uint256) {
        uint256 supply = ClaimSeriesToken(s.claimToken).totalSupply();
        uint256 raw = Math.mulDiv(supply, s.rateX18, 1e18, Math.Rounding.Ceil);
        if (s.officialDecimals < 18) return (raw + (10 ** (18 - s.officialDecimals)) - 1) / (10 ** (18 - s.officialDecimals));
        if (s.officialDecimals > 18) return raw * (10 ** (s.officialDecimals - 18));
        return raw;
    }

    function _unitRequirement(uint256 refPriceUsd, uint16 tierBps, uint8 dec) internal pure returns (uint256) {
        uint256 scale = 10 ** dec;
        return Math.mulDiv(refPriceUsd, uint256(tierBps) * scale, BPS * 1e18, Math.Rounding.Ceil);
    }

    function _priceAtoms(Series storage s) internal view returns (uint256) {
        return Math.mulDiv(s.refPriceUsd, 10 ** markets[s.marketId].assetDecimals, 1e18, Math.Rounding.Ceil);
    }

    function _openSeller(bytes32 seriesId) internal view returns (Series storage s) {
        s = seriesOf[seriesId];
        if (s.claimToken == address(0)) revert Unknown();
        if (msg.sender != s.seller) revert NotSeller();
        if (s.state != State.OPEN) revert BadState();
    }

    function _openOrResolvedSeller(bytes32 seriesId) internal view returns (Series storage s) {
        s = seriesOf[seriesId];
        if (s.claimToken == address(0)) revert Unknown();
        if (msg.sender != s.seller) revert NotSeller();
        if (s.state != State.OPEN && s.state != State.RESOLVED) revert BadState();
    }

    function _ticker(string memory base, uint256 refPriceUsd, uint16 tierBps) internal pure returns (string memory) {
        return string.concat("hPer", base, "Pts-", _u(refPriceUsd / 1e18), "-", _u(uint256(tierBps) / BPS), "X");
    }

    function _u(uint256 n) internal pure returns (string memory) {
        if (n == 0) return "0";
        uint256 j = n;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory b = new bytes(len);
        while (n != 0) {
            b[--len] = bytes1(uint8(48 + n % 10));
            n /= 10;
        }
        return string(b);
    }
}
