// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LeafOApp} from "./LeafOApp.sol";
import {LeafYieldFee} from "./LeafYieldFee.sol";
import {IVeNft} from "./IVeNft.sol";
import {LeafVePolicy} from "./LeafVePolicy.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";

/// @title LeafNftLockbox
/// @notice C1 source for permanent veNFTs (hveAERO first). Dest shares use
///         vault math: first wrap 1:1, later wraps mint assets * supply / backing
///         so Maxi compounding is not diluted. Cap is on live AERO, not shares.
///         No protocol redeem. No vote / merge / split / withdrawManaged.
///         After take, Base wraps call Voter.depositManaged into veAERO Maxi.
contract LeafNftLockbox is LeafOApp, ReentrancyGuard, LeafYieldFee, IERC721Receiver {
    using SafeERC20 for IERC20;

    IVeNft public immutable ve;
    uint256 public depositCap;
    uint256 public totalLocked;
    uint256 public maxNfts;
    uint256[] public ids;
    uint256 public maxPrincipalPerNft;
    mapping(uint256 => uint256) public principalOf;

    address private _expectedSender;
    uint256 private _expectedTokenId;
    bool private _expectingNft;

    event BridgedOut(
        address indexed from, uint32 indexed dstEid, bytes32 to, uint256 tokenId, uint256 assets, uint256 shares, bytes32 guid
    );
    event CapUpdated(uint256 cap);
    event NftUnhealthy(uint256 indexed tokenId);

    error ZeroAmount();
    error CapExceeded();
    error InboundOnly();
    error BadNft();
    error AlreadyHeld();
    error TooManyNfts();
    error UnexpectedNftTransfer();

    constructor(
        address ve_,
        address endpoint_,
        address owner_,
        address guardian_,
        address feeRecipient_,
        uint256 depositCap_
    ) LeafOApp(endpoint_, owner_, guardian_) {
        if (ve_ == address(0)) revert ZeroAddress();
        ve = IVeNft(ve_);
        depositCap = depositCap_;
        maxNfts = 64;
        maxPrincipalPerNft = 100_000e18;
        _initFee(feeRecipient_);
    }

    function canonicalInner() public pure override returns (address) {
        return address(0);
    }

    function setDepositCap(uint256 cap) external onlyOwner {
        if (depositCap != 0 && cap > depositCap) revert CapIncrease();
        depositCap = cap;
        emit CapUpdated(cap);
    }

    function setMaxNfts(uint256 n) external onlyOwner {
        if (n == 0 || (maxNfts != 0 && n > maxNfts)) revert CapIncrease();
        maxNfts = n;
    }

    function setMaxPrincipalPerNft(uint256 n) external onlyOwner {
        if (n == 0 || (maxPrincipalPerNft != 0 && n > maxPrincipalPerNft)) revert CapIncrease();
        maxPrincipalPerNft = n;
    }

    /// @notice Burned / left / unlocked / short of wrap principal → false.
    function nftHealthy(uint256 id) public view returns (bool) {
        if (principalOf[id] == 0) return false;
        return LeafVePolicy.heldOk(ve, address(this), id, principalOf[id]);
    }

    /// @notice Anyone. Permanent lock broken, amount below wrap principal, or NFT left.
    function reportNftHealth() external {
        uint256 n = ids.length;
        for (uint256 i; i < n; ++i) {
            uint256 id = ids[i];
            if (!this.nftHealthy(id)) {
                _degrade(id);
                return;
            }
        }
    }

    function _degrade(uint256 id) internal {
        emit NftUnhealthy(id);
        if (uint8(health) < uint8(Health.Degraded)) {
            health = Health.Degraded;
            emit HealthSet(Health.Degraded, msg.sender);
        }
    }

    function _requireRestoreProof() internal view override {
        uint256 n = ids.length;
        for (uint256 i; i < n; ++i) {
            if (!this.nftHealthy(ids[i])) revert NotSolvent();
        }
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

    /// @notice Side-token bribes sitting on this box. Never the veNFT. Never AERO-in-NFT.
    function pullYield(IERC20 token, address to) external nonReentrant {
        _requireConvertOn();
        _requireConverter(to);
        if (address(token) == address(ve) || address(token) == LeafVePolicy.AERO) revert LeafVePolicy.ForbiddenVeCall();
        _pullYield(token, IERC20(address(0)), 0, to);
    }

    /// @notice Live locked AERO across held NFTs (Maxi-compounded). Not dest shares.
    function currentAssets() public view returns (uint256 sum) {
        uint256 n = ids.length;
        for (uint256 i; i < n; ++i) {
            uint256 id = ids[i];
            if (principalOf[id] == 0) continue;
            try ve.locked(id) returns (IVeNft.LockedBalance memory L) {
                if (L.amount > 0) sum += uint256(int256(L.amount));
            } catch {}
        }
    }

    /// @notice Dest shares a new `assets` wrap would mint. Floors in favor of existing holders.
    function previewShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalLocked;
        if (supply == 0) return assets;
        uint256 backing = currentAssets();
        if (backing == 0) return assets;
        return Math.mulDiv(assets, supply, backing);
    }

    function send(uint32 dstEid, bytes32 to, uint256 tokenId, address refund)
        public
        payable
        nonReentrant
        whenNotPaused
        returns (bytes32 guid)
    {
        if (to == bytes32(0)) revert ZeroAddress();
        _requireMint();

        uint256 assets = _takeNft(msg.sender, tokenId);
        uint256 backing = currentAssets();
        if (depositCap != 0 && backing + assets > depositCap) revert CapExceeded();
        if (ids.length >= maxNfts) revert TooManyNfts();

        uint256 shares = (totalLocked == 0 || backing == 0)
            ? assets
            : Math.mulDiv(assets, totalLocked, backing);
        if (shares == 0) revert ZeroAmount();

        totalLocked += shares;
        principalOf[tokenId] = assets;
        ids.push(tokenId);
        _takeQuota(assets);

        bytes memory payload = encodeBridge(to, shares);
        ILayerZeroEndpointV2.MessagingReceipt memory receipt =
            _lzSend(dstEid, payload, _defaultOptions(dstEid), refund == address(0) ? msg.sender : refund);
        emit BridgedOut(msg.sender, dstEid, to, tokenId, assets, shares, receipt.guid);
        return receipt.guid;
    }

    function sendTo(uint32 dstEid, address to, uint256 tokenId) external payable returns (bytes32) {
        return send(dstEid, bytes32(uint256(uint160(to))), tokenId, msg.sender);
    }

    function _lzReceive(ILayerZeroEndpointV2.Origin calldata, bytes32, bytes calldata, address, bytes calldata)
        internal
        override
    {
        revert InboundOnly();
    }

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata) external view returns (bytes4) {
        if (msg.sender != address(ve)) revert BadNft();
        if (!_expectingNft || from != _expectedSender || tokenId != _expectedTokenId) revert UnexpectedNftTransfer();
        return IERC721Receiver.onERC721Received.selector;
    }

    function heldCount() external view returns (uint256) {
        return ids.length;
    }

    function _takeNft(address from, uint256 tokenId) internal returns (uint256 principal) {
        if (tokenId == 0) revert BadNft();
        if (principalOf[tokenId] != 0) revert AlreadyHeld();
        if (ids.length >= maxNfts) revert TooManyNfts();
        if (ve.escrowType(tokenId) != IVeNft.EscrowType.NORMAL) revert BadNft();
        IVeNft.LockedBalance memory L = ve.locked(tokenId);
        if (!L.isPermanent) revert BadNft();
        if (L.amount <= 0) revert ZeroAmount();
        if (ve.voted(tokenId) || ve.attachments(tokenId) != 0) revert BadNft();
        principal = uint256(int256(L.amount));
        if (principal == 0) revert ZeroAmount();
        if (maxPrincipalPerNft != 0 && principal > maxPrincipalPerNft) revert CapExceeded();
        _expectedSender = from;
        _expectedTokenId = tokenId;
        _expectingNft = true;
        ve.safeTransferFrom(from, address(this), tokenId);
        _expectingNft = false;
        _expectedSender = address(0);
        _expectedTokenId = 0;
        if (ve.ownerOf(tokenId) != address(this)) revert BadNft();
        if (block.chainid == 8453) {
            (bool ok,) = LeafVePolicy.VOTER.call(
                abi.encodeWithSelector(LeafVePolicy.DEPOSIT_MANAGED, tokenId, LeafVePolicy.MAXI_ID)
            );
            if (!ok || ve.escrowType(tokenId) != IVeNft.EscrowType.LOCKED) revert BadNft();
        }
    }
}
