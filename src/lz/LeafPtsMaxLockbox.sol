// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LeafOApp} from "./LeafOApp.sol";
import {LeafYieldFee} from "./LeafYieldFee.sol";
import {LeafPtsMaxPolicy as P} from "./LeafPtsMaxPolicy.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";

/// @title LeafPtsMaxLockbox
/// @notice C1 source for PTSMAX. User deposits River Pts; this box convert()s
///         epoch 7 into an sRIVER_V2 NFT it holds. Dest shares = RIVER out, not Pts.
///         No protocol redeem. Merkle weekly Pts stays off until this address
///         appears in River's tree (same class as KAITO extra-chain).
contract LeafPtsMaxLockbox is LeafOApp, ReentrancyGuard, LeafYieldFee, IERC721Receiver {
    using SafeERC20 for IERC20;

    IERC20 public immutable pts;
    address public immutable convert;
    IERC721 public immutable sRiver;

    uint256 public depositCap;
    uint256 public totalLocked;
    uint256[] public ids;
    mapping(uint256 => uint256) public principalOf;
    bool public merkleEnabled;

    uint256 private _lastNft;
    bool private _expectingNft;

    event BridgedOut(address indexed from, uint32 indexed dstEid, bytes32 to, uint256 ptsIn, uint256 riverOut, bytes32 guid);
    event CapUpdated(uint256 cap);
    event MerkleEnabled(bool on);
    event NftUnhealthy(uint256 indexed tokenId);

    error ZeroAmount();
    error CapExceeded();
    error InboundOnly();
    error BadConvert();
    error BadNft();
    error MerkleOff();
    error UnexpectedNftTransfer();

    constructor(
        address pts_,
        address convert_,
        address sRiver_,
        address endpoint_,
        address owner_,
        address guardian_,
        address feeRecipient_,
        uint256 depositCap_
    ) LeafOApp(endpoint_, owner_, guardian_) {
        if (pts_ == address(0) || convert_ == address(0) || sRiver_ == address(0)) revert ZeroAddress();
        if (sRiver_ == P.SRIVER_V1) revert P.V1Forbidden();
        pts = IERC20(pts_);
        convert = convert_;
        sRiver = IERC721(sRiver_);
        depositCap = depositCap_;
        _initFee(feeRecipient_);
    }

    function canonicalInner() public view override returns (address) {
        return address(pts);
    }

    function setDepositCap(uint256 cap) external onlyOwner {
        if (depositCap != 0 && cap > depositCap) revert CapIncrease();
        depositCap = cap;
        emit CapUpdated(cap);
    }

    /// @notice Off until this lockbox is a merkle leaf. Do not enable at deploy.
    function setMerkleEnabled(bool on) external onlyOwner {
        merkleEnabled = on;
        emit MerkleEnabled(on);
    }

    function send(uint32 dstEid, bytes32 to, uint256 ptsIn, uint256 minRiverOut, address refund)
        public
        payable
        nonReentrant
        whenNotPaused
        returns (bytes32 guid)
    {
        if (ptsIn == 0) revert ZeroAmount();
        if (to == bytes32(0)) revert ZeroAddress();
        _requireMint();
        _requireInnerSupplyOk(pts);

        pts.safeTransferFrom(msg.sender, address(this), ptsIn);
        uint256 riverOut = _convert(ptsIn, minRiverOut);
        if (totalLocked + riverOut > depositCap) revert CapExceeded();
        totalLocked += riverOut;
        _takeQuota(riverOut);

        bytes memory payload = encodeBridge(to, riverOut);
        ILayerZeroEndpointV2.MessagingReceipt memory receipt =
            _lzSend(dstEid, payload, _defaultOptions(dstEid), refund == address(0) ? msg.sender : refund);
        emit BridgedOut(msg.sender, dstEid, to, ptsIn, riverOut, receipt.guid);
        return receipt.guid;
    }

    function sendTo(uint32 dstEid, address to, uint256 ptsIn, uint256 minRiverOut) external payable returns (bytes32) {
        return send(dstEid, bytes32(uint256(uint160(to))), ptsIn, minRiverOut, msg.sender);
    }

    /// @notice Keeper path. Reverts until owner sees this box in a weekly tree.
    function claimWeeklyPts(uint256 index, uint256 amount, bytes32[] calldata proof) external nonReentrant {
        if (!merkleEnabled) revert MerkleOff();
        if (msg.sender != harvester && msg.sender != owner()) revert BadConvert();
        (bool ok,) = P.PTS_MERKLE.call(abi.encodeWithSelector(P.CLAIM_PTS_SEL, index, amount, proof));
        if (!ok) revert BadConvert();
        uint256 idle = pts.balanceOf(address(this));
        if (idle == 0) return;
        uint256 added = _convert(idle, 0);
        totalLocked += added;
    }

    function nftHealthy(uint256 id) public view returns (bool) {
        if (principalOf[id] == 0) return false;
        try sRiver.ownerOf(id) returns (address o) {
            return o == address(this);
        } catch {
            return false;
        }
    }

    function reportNftHealth() external {
        uint256 n = ids.length;
        for (uint256 i; i < n; ++i) {
            if (!nftHealthy(ids[i])) {
                emit NftUnhealthy(ids[i]);
                if (uint8(health) < uint8(Health.Degraded)) {
                    health = Health.Degraded;
                    emit HealthSet(Health.Degraded, msg.sender);
                }
                return;
            }
        }
    }

    function heldCount() external view returns (uint256) {
        return ids.length;
    }

    function _lzReceive(ILayerZeroEndpointV2.Origin calldata, bytes32, bytes calldata, address, bytes calldata)
        internal
        pure
        override
    {
        revert InboundOnly();
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata) external returns (bytes4) {
        if (msg.sender != address(sRiver)) revert BadNft();
        if (!_expectingNft) revert UnexpectedNftTransfer();
        _lastNft = tokenId;
        return IERC721Receiver.onERC721Received.selector;
    }

    function _convert(uint256 ptsIn, uint256 minRiverOut) internal returns (uint256 riverOut) {
        pts.forceApprove(convert, ptsIn);
        _expectingNft = true;
        _lastNft = 0;
        (bool ok, bytes memory ret) =
            convert.call(abi.encodeWithSelector(P.CONVERT_SEL, ptsIn, P.P1, P.EPOCH_MAX, minRiverOut));
        _expectingNft = false;
        pts.forceApprove(convert, 0);
        if (!ok || ret.length < 32) revert BadConvert();
        riverOut = abi.decode(ret, (uint256));
        if (riverOut == 0) revert ZeroAmount();
        uint256 id = _lastNft;
        if (id == 0 || sRiver.ownerOf(id) != address(this)) revert BadNft();
        if (principalOf[id] == 0) ids.push(id);
        principalOf[id] += riverOut;
    }
}
