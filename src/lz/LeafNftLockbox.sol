// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LeafOApp} from "./LeafOApp.sol";
import {LeafYieldFee} from "./LeafYieldFee.sol";
import {IVeNft} from "./IVeNft.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";

/// @title LeafNftLockbox
/// @notice C1 source for permanent veNFTs (hveAERO first). Mints dest ClosedOFT
///         shares = locked AERO amount. Time-locked / managed / decaying NFTs
///         are rejected — those cannot share a fungible ticket.
///         No protocol redeem. No vote / merge / split / withdraw.
contract LeafNftLockbox is LeafOApp, ReentrancyGuard, LeafYieldFee, IERC721Receiver {
    using SafeERC20 for IERC20;

    IVeNft public immutable ve;
    uint256 public depositCap;
    uint256 public totalLocked;
    uint256 public maxNfts;
    uint256[] public ids;
    uint256 public maxPrincipalPerNft;
    mapping(uint256 => uint256) public principalOf;

    event BridgedOut(address indexed from, uint32 indexed dstEid, bytes32 to, uint256 tokenId, uint256 principal, bytes32 guid);
    event CapUpdated(uint256 cap);
    event NftUnhealthy(uint256 indexed tokenId);

    error ZeroAmount();
    error CapExceeded();
    error InboundOnly();
    error BadNft();
    error AlreadyHeld();
    error TooManyNfts();

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

    /// @notice Anyone. Permanent lock broken, amount below wrap principal, or NFT left.
    function reportNftHealth() external {
        uint256 n = ids.length;
        for (uint256 i; i < n; ++i) {
            uint256 id = ids[i];
            if (ve.ownerOf(id) != address(this)) {
                _degrade(id);
                return;
            }
            IVeNft.LockedBalance memory L = ve.locked(id);
            uint256 amt = L.amount <= 0 ? 0 : uint256(int256(L.amount));
            if (!L.isPermanent || ve.escrowType(id) != IVeNft.EscrowType.NORMAL || amt < principalOf[id]) {
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
        if (address(token) == address(ve)) revert BadNft();
        _pullYield(token, IERC20(address(0)), 0, to);
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

        uint256 principal = _takeNft(msg.sender, tokenId);
        if (totalLocked + principal > depositCap) revert CapExceeded();
        if (ids.length >= maxNfts) revert TooManyNfts();
        totalLocked += principal;
        principalOf[tokenId] = principal;
        ids.push(tokenId);
        _takeQuota(principal);

        bytes memory payload = encodeBridge(to, principal);
        ILayerZeroEndpointV2.MessagingReceipt memory receipt =
            _lzSend(dstEid, payload, _defaultOptions(), refund == address(0) ? msg.sender : refund);
        emit BridgedOut(msg.sender, dstEid, to, tokenId, principal, receipt.guid);
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

    function onERC721Received(address, address, uint256, bytes calldata) external view returns (bytes4) {
        if (msg.sender != address(ve)) revert BadNft();
        return IERC721Receiver.onERC721Received.selector;
    }

    function heldCount() external view returns (uint256) {
        return ids.length;
    }

    function _takeNft(address from, uint256 tokenId) internal returns (uint256 principal) {
        if (tokenId == 0) revert BadNft();
        if (principalOf[tokenId] != 0) revert AlreadyHeld();
        if (ve.escrowType(tokenId) != IVeNft.EscrowType.NORMAL) revert BadNft();
        IVeNft.LockedBalance memory L = ve.locked(tokenId);
        if (!L.isPermanent) revert BadNft();
        if (L.amount <= 0) revert ZeroAmount();
        principal = uint256(int256(L.amount));
        if (principal == 0) revert ZeroAmount();
        if (maxPrincipalPerNft != 0 && principal > maxPrincipalPerNft) revert CapExceeded();
        ve.safeTransferFrom(from, address(this), tokenId);
        if (ve.ownerOf(tokenId) != address(this)) revert BadNft();
    }
}
