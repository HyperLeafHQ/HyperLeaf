// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "./interfaces/ILayerZeroEndpointV2.sol";
import {OptionsBuilder} from "./OptionsBuilder.sol";
import {LayerZeroAddresses} from "./LayerZeroAddresses.sol";

/// @notice Shared OApp + Liquid-peg guards (2026-09-07 L-BTC analog).
///         Messages bind listingTag. Bridge starts closed. Guardian can halt
///         before assets leave. Per-tx and per-day caps. One contract, one asset.
abstract contract LeafOApp is Ownable2Step, Pausable {
    ILayerZeroEndpointV2 public immutable endpoint;
    address public guardian;
    mapping(uint32 eid => bytes32 peer) public peers;
    /// @dev Permanently frozen once the bridge is opened for the first time.
    bool public peersFrozen;

    /// @dev Frozen after first set. Encoded in every LZ payload so a proof
    ///      cannot be replayed against a different listing (Liquid range-proof cache).
    bytes32 public listingTag;
    /// @dev Owner opens only after on-chain peer + DVN + cap check. Default false.
    bool public bridgeOpen;
    uint256 public maxPerTx;
    uint256 public maxPerDay;
    uint64 public windowStart;
    uint256 public windowVolume;
    uint64 public constant WINDOW = 1 days;

    event PeerSet(uint32 indexed eid, bytes32 peer);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event ListingTagSet(bytes32 tag);
    event LimitsSet(uint256 maxPerTx, uint256 maxPerDay);
    event BridgeOpened();
    event BridgeClosed();
    event HealthSet(Health indexed health, address indexed caller);
    event InnerSupplyCeilingSet(uint256 cap);

    enum Health {
        Normal,
        Degraded,
        Halted,
        Insolvent
    }

    /// @dev Normal: mint+redeem. Degraded: redeem only (upstream suspect).
    ///      Halted/Insolvent: neither. Guardian may only worsen. Owner restores
    ///      Degraded/Halted. Insolvent needs recoverInsolvent().
    Health public health;
    /// @dev If inner.totalSupply() exceeds this, mint stops (upstream print).
    ///      0 = unset (do not skip: openBridge requires it on lockboxes).
    uint256 public innerSupplyCeiling;

    error ZeroAddress();
    error OnlyEndpoint();
    error OnlyPeer();
    error NoPeer();
    error NotGuardian();
    error NoListingTag();
    error TagFrozen();
    error LimitsUnset();
    error BridgeClosedErr();
    error WrongListing();
    error TxCapExceeded();
    error DayCapExceeded();
    error Underbacked();
    error NotHealthy();
    error NotSolvent();
    error HealthUpgrade();
    error InnerSupplyBreach();
    error PeerFrozen();
    error CapIncrease();
    error ConfigFrozen();
    error NotSolanaRecipient();

    modifier onlyGuardian() {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardian();
        _;
    }

    constructor(address _endpoint, address _owner, address _guardian) Ownable(_owner) {
        if (_endpoint == address(0) || _owner == address(0) || _guardian == address(0)) revert ZeroAddress();
        endpoint = ILayerZeroEndpointV2(_endpoint);
        guardian = _guardian;
        endpoint.setDelegate(_owner);
    }

    function setGuardian(address _guardian) external onlyOwner {
        if (_guardian == address(0)) revert ZeroAddress();
        emit GuardianUpdated(guardian, _guardian);
        guardian = _guardian;
    }

    function setPeer(uint32 eid, bytes32 peer) public onlyOwner {
        if (peersFrozen) revert PeerFrozen();
        if (peers[eid] != bytes32(0) && peers[eid] != peer) revert PeerFrozen();
        if (peer == bytes32(0)) revert NoPeer();
        peers[eid] = peer;
        emit PeerSet(eid, peer);
    }

    function setPeer(uint32 eid, address peer) external onlyOwner {
        setPeer(eid, bytes32(uint256(uint160(peer))));
    }

    function setListingTag(bytes32 tag) public onlyOwner {
        if (tag == bytes32(0)) revert NoListingTag();
        if (listingTag != bytes32(0) && listingTag != tag) revert TagFrozen();
        listingTag = tag;
        emit ListingTagSet(tag);
    }

    function setLimits(uint256 maxTx, uint256 maxDay) public onlyOwner {
        if (maxTx == 0 || maxDay == 0 || maxTx > maxDay) revert LimitsUnset();
        if (maxPerTx != 0 && maxTx > maxPerTx) revert CapIncrease();
        if (maxPerDay != 0 && maxDay > maxPerDay) revert CapIncrease();
        maxPerTx = maxTx;
        maxPerDay = maxDay;
        emit LimitsSet(maxTx, maxDay);
    }

    function setInnerSupplyCeiling(uint256 cap) public onlyOwner {
        if (innerSupplyCeiling != 0 && cap > innerSupplyCeiling) revert CapIncrease();
        innerSupplyCeiling = cap;
        emit InnerSupplyCeilingSet(cap);
    }

    function setHealth(Health next) public onlyGuardian {
        if (uint8(next) <= uint8(health)) revert HealthUpgrade();
        health = next;
        emit HealthSet(next, msg.sender);
    }

    function restoreHealth(Health next) external onlyOwner {
        if (health == Health.Insolvent) revert NotSolvent();
        if (uint8(next) >= uint8(health)) revert HealthUpgrade();
        if (next == Health.Normal) _requireRestoreProof();
        health = next;
        emit HealthSet(next, msg.sender);
    }

    function recoverInsolvent() external onlyOwner {
        if (health != Health.Insolvent) revert HealthUpgrade();
        health = Health.Halted;
        emit HealthSet(Health.Halted, msg.sender);
    }

    /// @dev Source lockboxes override. Dest OFT has none — ceiling DoS does not apply.
    function canonicalInner() public view virtual returns (address) {
        return address(0);
    }

    /// @notice Anyone. Canonical inner only — not an arbitrary ERC20.
    function reportInnerSupply() external {
        address token = canonicalInner();
        if (innerSupplyCeiling == 0 || token == address(0)) return;
        if (IERC20(token).totalSupply() <= innerSupplyCeiling) return;
        if (uint8(health) < uint8(Health.Degraded)) {
            health = Health.Degraded;
            emit HealthSet(Health.Degraded, msg.sender);
        }
    }

    function _requireRestoreProof() internal view virtual {
        address token = canonicalInner();
        if (token == address(0) || innerSupplyCeiling == 0) return;
        if (IERC20(token).totalSupply() > innerSupplyCeiling) revert InnerSupplyBreach();
    }

    /// @notice Call after peers, DVN, caps, and listingTag are on-chain. Not a git merge.
    function openBridge() public virtual onlyOwner {
        if (listingTag == bytes32(0)) revert NoListingTag();
        if (maxPerTx == 0 || maxPerDay == 0) revert LimitsUnset();
        peersFrozen = true;
        bridgeOpen = true;
        emit BridgeOpened();
    }

    /// @notice Halt mint and redeem. Independent of owner. Unpause does not reopen the bridge.
    function closeBridge() external onlyGuardian {
        bridgeOpen = false;
        if (!paused()) _pause();
        emit BridgeClosed();
    }

    function pause() external onlyGuardian {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setEndpointConfig(address lib, SetConfigParam[] calldata params) external onlyOwner {
        if (bridgeOpen && !paused()) revert ConfigFrozen();
        endpoint.setConfig(address(this), lib, params);
    }

    function quote(uint32 dstEid, bytes memory message, bytes memory options, bool payInLzToken)
        public
        view
        returns (uint256 nativeFee, uint256 lzTokenFee)
    {
        bytes32 peer = peers[dstEid];
        if (peer == bytes32(0)) revert NoPeer();
        ILayerZeroEndpointV2.MessagingFee memory fee = endpoint.quote(
            ILayerZeroEndpointV2.MessagingParams(dstEid, peer, message, options, payInLzToken), address(this)
        );
        return (fee.nativeFee, fee.lzTokenFee);
    }

    function encodeBridge(bytes32 to, uint256 amount) public view returns (bytes memory) {
        return abi.encode(listingTag, to, amount);
    }

    /// @notice Native fee for `sendTo(dstEid, to, amount)` with default lzReceive gas.
    ///         Solana destinations must use `quoteSend(dstEid, bytes32, amount)` — a 20-byte
    ///         EVM address would unlock JitoSOL to an ATA nobody owns.
    function quoteSend(uint32 dstEid, address to, uint256 amount) external view returns (uint256 nativeFee) {
        return quoteSend(dstEid, bytes32(uint256(uint160(to))), amount);
    }

    function quoteSend(uint32 dstEid, bytes32 to, uint256 amount) public view returns (uint256 nativeFee) {
        _requireRemoteTo(dstEid, to);
        bytes memory payload = encodeBridge(to, amount);
        (nativeFee,) = quote(dstEid, payload, _defaultOptions(dstEid), false);
    }

    function lzReceive(
        ILayerZeroEndpointV2.Origin calldata origin,
        bytes32 guid,
        bytes calldata message,
        address executor,
        bytes calldata extraData
    ) external payable {
        if (msg.sender != address(endpoint)) revert OnlyEndpoint();
        if (peers[origin.srcEid] != origin.sender) revert OnlyPeer();
        _lzReceive(origin, guid, message, executor, extraData);
    }

    function _lzSend(uint32 dstEid, bytes memory message, bytes memory options, address refund)
        internal
        returns (ILayerZeroEndpointV2.MessagingReceipt memory)
    {
        bytes32 peer = peers[dstEid];
        if (peer == bytes32(0)) revert NoPeer();
        return endpoint.send{value: msg.value}(
            ILayerZeroEndpointV2.MessagingParams(dstEid, peer, message, options, false), refund
        );
    }

    function _defaultOptions() internal pure returns (bytes memory) {
        return OptionsBuilder.lzReceiveOption(LayerZeroAddresses.LZ_RECEIVE_GAS);
    }

    function _defaultOptions(uint32 dstEid) internal pure returns (bytes memory) {
        if (dstEid == LayerZeroAddresses.EID_SOLANA) {
            return OptionsBuilder.lzReceiveOption(LayerZeroAddresses.LZ_RECEIVE_SOLANA_CU);
        }
        return _defaultOptions();
    }

    /// @dev Solana recipients are 32-byte pubkeys. Left-padded 20-byte EVM addresses
    ///      would credit an ATA that no wallet controls.
    function _requireRemoteTo(uint32 dstEid, bytes32 to) internal pure {
        if (to == bytes32(0)) revert ZeroAddress();
        if (dstEid == LayerZeroAddresses.EID_SOLANA && bytes12(to) == 0) revert NotSolanaRecipient();
    }

    function _takeQuota(uint256 amount) internal {
        if (!bridgeOpen) revert BridgeClosedErr();
        if (amount > maxPerTx) revert TxCapExceeded();
        if (block.timestamp >= uint256(windowStart) + WINDOW) {
            windowStart = uint64(block.timestamp);
            windowVolume = 0;
        }
        windowVolume += amount;
        if (windowVolume > maxPerDay) revert DayCapExceeded();
    }

    function _requireMint() internal view {
        if (health != Health.Normal) revert NotHealthy();
    }

    function _requireRedeem() internal view {
        if (uint8(health) >= uint8(Health.Halted)) revert NotSolvent();
    }

    function _requireInnerSupplyOk(IERC20 inner) internal view {
        if (innerSupplyCeiling == 0) return;
        if (inner.totalSupply() > innerSupplyCeiling) revert InnerSupplyBreach();
    }

    function _decodeBridge(bytes calldata message) internal view returns (bytes32 to, uint256 amount) {
        bytes32 tag;
        (tag, to, amount) = abi.decode(message, (bytes32, bytes32, uint256));
        if (tag != listingTag || tag == bytes32(0)) revert WrongListing();
    }

    /// @dev Pay only if cash is on this contract. Do not trust burn/ticket alone.
    function _requireCash(IERC20 token, uint256 assets, uint256 reservedOther) internal view {
        if (token.balanceOf(address(this)) < reservedOther + assets) revert Underbacked();
    }

    function _lzReceive(
        ILayerZeroEndpointV2.Origin calldata origin,
        bytes32 guid,
        bytes calldata message,
        address executor,
        bytes calldata extraData
    ) internal virtual;
}
