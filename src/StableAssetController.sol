// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IStableAssetAdapter} from "./interfaces/IStableAssetAdapter.sol";
import {IStableExitBuffer} from "./interfaces/IStableExitBuffer.sol";

/// @title StableAssetController
/// @notice Generic protocol-side protection layer for stable-asset Leaf listings.
///
/// The controller does NOT guarantee an external stablecoin peg. It turns venue
/// evidence into explicit protocol states and a market/exit policy. Leaf Market
/// remains the secondary liquidity venue; this contract is the risk gate beneath it.
contract StableAssetController is Ownable2Step, Pausable {
    uint256 public constant BPS = 10_000;
    uint256 public constant ONE = 1e18;

    enum PegStatus {
        Normal,
        Warning,
        Degraded,
        Broken
    }

    enum ExitMode {
        MarketOnly,
        PrimaryRedeem,
        BufferedRedeem,
        QueueRedeem,
        Frozen
    }

    struct RiskConfig {
        uint16 maxPegDeviationBps;
        uint16 maxExitDiscountBps;
        uint16 minExitCoverageBps;
        uint32 maxEvidenceAge;
        uint16 maxPrimaryRedeemSlippageBps;
        bool requirePrimaryRedeem;
    }

    struct Listing {
        address leaf;
        address adapter;
        address buffer;
        bool enabled;
    }

    struct Assessment {
        PegStatus pegStatus;
        ExitMode exitMode;
        bool evidenceFresh;
        bool marketEnabled;
        bool primaryExitAllowed;
        uint256 pegPrice;
        uint256 exitCoverageBps;
        uint256 primaryRedeemPrice;
        uint256 effectiveExitPrice;
    }

    mapping(bytes32 listingId => Listing) public listings;
    mapping(bytes32 listingId => RiskConfig) public riskConfigs;

    event ListingRegistered(bytes32 indexed listingId, address indexed leaf, address indexed adapter, address buffer);
    event ListingEnabled(bytes32 indexed listingId, bool enabled);
    event BufferSet(bytes32 indexed listingId, address indexed buffer);
    event RiskConfigSet(
        bytes32 indexed listingId,
        uint16 maxPegDeviationBps,
        uint16 maxExitDiscountBps,
        uint16 minExitCoverageBps,
        uint32 maxEvidenceAge,
        uint16 maxPrimaryRedeemSlippageBps,
        bool requirePrimaryRedeem
    );
    event PausedByOwner();
    event UnpausedByOwner();

    error InvalidListing();
    error InvalidConfig();
    error EvidenceStale();
    error PegNotHealthy();
    error ExitNotHealthy();

    constructor(address initialOwner) Ownable(initialOwner) {}

    function registerListing(bytes32 listingId, address leaf, address adapter, address buffer)
        external
        onlyOwner
    {
        if (listingId == bytes32(0) || leaf == address(0) || adapter == address(0)) revert InvalidListing();
        listings[listingId] = Listing({leaf: leaf, adapter: adapter, buffer: buffer, enabled: true});
        emit ListingRegistered(listingId, leaf, adapter, buffer);
    }

    function setEnabled(bytes32 listingId, bool enabled) external onlyOwner {
        Listing storage l = listings[listingId];
        if (l.leaf == address(0)) revert InvalidListing();
        l.enabled = enabled;
        emit ListingEnabled(listingId, enabled);
    }

    function setBuffer(bytes32 listingId, address buffer) external onlyOwner {
        Listing storage l = listings[listingId];
        if (l.leaf == address(0)) revert InvalidListing();
        l.buffer = buffer;
        emit BufferSet(listingId, buffer);
    }

    function setRiskConfig(bytes32 listingId, RiskConfig calldata cfg) external onlyOwner {
        if (listings[listingId].leaf == address(0)) revert InvalidListing();
        if (
            cfg.maxPegDeviationBps > BPS || cfg.maxExitDiscountBps > BPS || cfg.minExitCoverageBps > BPS
                || cfg.maxPrimaryRedeemSlippageBps > BPS
        ) revert InvalidConfig();
        riskConfigs[listingId] = cfg;
        emit RiskConfigSet(
            listingId,
            cfg.maxPegDeviationBps,
            cfg.maxExitDiscountBps,
            cfg.minExitCoverageBps,
            cfg.maxEvidenceAge,
            cfg.maxPrimaryRedeemSlippageBps,
            cfg.requirePrimaryRedeem
        );
    }

    function pause() external onlyOwner {
        _pause();
        emit PausedByOwner();
    }

    function unpause() external onlyOwner {
        _unpause();
        emit UnpausedByOwner();
    }

    /// @notice Returns the normalized health state consumed by Leaf Market / UI / keepers.
    ///         A market discount is ordinary liquidity pricing only when `marketEnabled` is true.
    function assess(bytes32 listingId) public view returns (Assessment memory a) {
        Listing memory l = listings[listingId];
        if (l.leaf == address(0) || l.adapter == address(0) || !l.enabled) revert InvalidListing();
        RiskConfig memory cfg = riskConfigs[listingId];
        IStableAssetAdapter adapter = IStableAssetAdapter(l.adapter);
        IStableAssetAdapter.PegState memory peg = adapter.pegState(listingId);
        IStableAssetAdapter.ExitState memory ex = adapter.exitState(listingId);

        a.pegPrice = peg.marketPrice;
        a.primaryRedeemPrice = peg.primaryRedeemPrice;
        a.evidenceFresh = _fresh(peg.updatedAt, ex.updatedAt, cfg.maxEvidenceAge);
        a.pegStatus = _pegStatus(peg, cfg, a.evidenceFresh);

        uint256 claim = ex.totalClaim;
        uint256 liquid = ex.immediatelyRedeemable + ex.bufferedLiquidity;
        a.exitCoverageBps = claim == 0 ? BPS : _min(BPS, (liquid * BPS) / claim);

        bool primaryHealthy = peg.referencePrice > 0 && peg.primaryRedeemPrice > 0
            && _discountBps(peg.primaryRedeemPrice, peg.referencePrice) <= cfg.maxPrimaryRedeemSlippageBps;
        bool coverageHealthy = claim == 0 || a.exitCoverageBps >= cfg.minExitCoverageBps;
        a.primaryExitAllowed = a.evidenceFresh && a.pegStatus <= PegStatus.Warning && primaryHealthy;

        if (!a.evidenceFresh || a.pegStatus == PegStatus.Broken) {
            a.marketEnabled = false;
            a.exitMode = ExitMode.Frozen;
        } else if (cfg.requirePrimaryRedeem && a.primaryExitAllowed) {
            a.marketEnabled = coverageHealthy;
            a.exitMode = a.marketEnabled ? ExitMode.PrimaryRedeem : ExitMode.QueueRedeem;
        } else if (a.primaryExitAllowed && coverageHealthy) {
            a.marketEnabled = true;
            a.exitMode = ExitMode.PrimaryRedeem;
        } else if (coverageHealthy && ex.bufferedLiquidity > 0) {
            a.marketEnabled = a.pegStatus != PegStatus.Degraded;
            a.exitMode = a.marketEnabled ? ExitMode.BufferedRedeem : ExitMode.QueueRedeem;
        } else {
            a.marketEnabled = false;
            a.exitMode = ExitMode.QueueRedeem;
        }

        if (a.marketEnabled && cfg.maxExitDiscountBps < BPS) {
            uint256 effective = _effectiveExitPrice(peg.referencePrice, a.exitCoverageBps, peg.primaryRedeemPrice);
            a.effectiveExitPrice = effective;
            if (effective > 0 && _discountBps(effective, peg.referencePrice) > cfg.maxExitDiscountBps) {
                a.marketEnabled = false;
                a.exitMode = ExitMode.Frozen;
            }
        }
    }

    function canUseLeafMarket(bytes32 listingId) external view returns (bool) {
        return assess(listingId).marketEnabled;
    }

    function canPrimaryExit(bytes32 listingId) external view returns (bool) {
        return assess(listingId).primaryExitAllowed;
    }

    /// @notice Guard for mint/deposit entry paths. Stablecoin impairment is a solvency event,
    ///         not yield; callers should stop normal issuance when this returns false.
    function canMint(bytes32 listingId) external view returns (bool) {
        if (paused()) return false;
        Assessment memory a = assess(listingId);
        return a.pegStatus == PegStatus.Normal && a.evidenceFresh;
    }

    /// @notice Guard for a primary exit adapter integration. It intentionally does not custody
    ///         funds or perform the external redemption; the venue adapter remains responsible.
    function validatePrimaryExit(bytes32 listingId, uint256 shares) external view returns (uint256 assets) {
        Assessment memory a = assess(listingId);
        if (!a.primaryExitAllowed) revert ExitNotHealthy();
        IStableAssetAdapter adapter = IStableAssetAdapter(listings[listingId].adapter);
        uint256 slippageBps;
        (assets, slippageBps) = adapter.previewPrimaryExit(listingId, shares);
        if (slippageBps > riskConfigs[listingId].maxPrimaryRedeemSlippageBps) revert ExitNotHealthy();
    }

    function _pegStatus(IStableAssetAdapter.PegState memory p, RiskConfig memory cfg, bool fresh)
        internal
        pure
        returns (PegStatus)
    {
        if (!fresh || p.referencePrice == 0) return PegStatus.Broken;
        uint256 deviation = p.deviationBps;
        if (deviation == 0) deviation = _discountBps(p.marketPrice, p.referencePrice);
        if (deviation <= cfg.maxPegDeviationBps) return PegStatus.Normal;
        uint256 warning = (uint256(cfg.maxPegDeviationBps) * 3) / 2;
        if (deviation <= warning) return PegStatus.Warning;
        if (deviation <= uint256(cfg.maxPegDeviationBps) * 2) return PegStatus.Degraded;
        return PegStatus.Broken;
    }

    function _fresh(uint256 pegUpdatedAt, uint256 exitUpdatedAt, uint32 maxAge) internal view returns (bool) {
        if (maxAge == 0 || pegUpdatedAt == 0 || exitUpdatedAt == 0) return false;
        if (pegUpdatedAt > block.timestamp || exitUpdatedAt > block.timestamp) return false;
        return block.timestamp - pegUpdatedAt <= maxAge && block.timestamp - exitUpdatedAt <= maxAge;
    }

    function _discountBps(uint256 value, uint256 reference) internal pure returns (uint256) {
        if (reference == 0 || value >= reference) return 0;
        return ((reference - value) * BPS) / reference;
    }

    function _effectiveExitPrice(uint256 reference, uint256 coverageBps, uint256 primaryPrice)
        internal
        pure
        returns (uint256)
    {
        if (reference == 0) return 0;
        if (primaryPrice == 0 || coverageBps >= BPS) return primaryPrice == 0 ? reference : primaryPrice;
        // Conservative blended floor: uncovered claim is priced at the lesser of the observed
        // primary exit price and zero. This produces a policy signal, not a promised redemption.
        return (primaryPrice * coverageBps) / BPS;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
