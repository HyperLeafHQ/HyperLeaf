// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";
import {OptionsBuilder} from "./OptionsBuilder.sol";

/// @dev Thin LZ peer for the claim board. Not a wrap OApp: no mint, no caps, no listingTag.
abstract contract LeafClaimPeer is Ownable2Step, Pausable {
    ILayerZeroEndpointV2 public immutable endpoint;
    address public guardian;
    mapping(uint32 eid => bytes32 peer) public peers;
    /// @dev First wired EID. New EIDs revert. Extra chains = new deploy.
    uint32 public remoteEid;

    error ZeroAddress();
    error OnlyEndpoint();
    error OnlyPeer();
    error NoPeer();
    error PeerFrozen();
    error NotGuardian();

    event PeerSet(uint32 indexed eid, bytes32 peer);
    event GuardianUpdated(address indexed oldG, address indexed newG);

    modifier onlyGuardian() {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardian();
        _;
    }

    constructor(address endpoint_, address owner_, address guardian_) Ownable(owner_) {
        if (endpoint_ == address(0) || owner_ == address(0) || guardian_ == address(0)) revert ZeroAddress();
        endpoint = ILayerZeroEndpointV2(endpoint_);
        guardian = guardian_;
        endpoint.setDelegate(owner_);
    }

    function setGuardian(address g) external onlyOwner {
        if (g == address(0)) revert ZeroAddress();
        emit GuardianUpdated(guardian, g);
        guardian = g;
    }

    function setPeer(uint32 eid, bytes32 peer) public onlyOwner {
        if (peer == bytes32(0)) revert ZeroAddress();
        if (remoteEid != 0 && eid != remoteEid) revert PeerFrozen();
        if (peers[eid] != bytes32(0) && peers[eid] != peer) revert PeerFrozen();
        peers[eid] = peer;
        remoteEid = eid;
        emit PeerSet(eid, peer);
    }

    function setPeer(uint32 eid, address peer) external onlyOwner {
        setPeer(eid, bytes32(uint256(uint160(peer))));
    }

    function pause() external onlyGuardian {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
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

    function quote(uint32 dstEid, bytes memory message, bytes memory options) public view returns (uint256 nativeFee) {
        bytes32 peer = peers[dstEid];
        if (peer == bytes32(0)) revert NoPeer();
        ILayerZeroEndpointV2.MessagingFee memory fee = endpoint.quote(
            ILayerZeroEndpointV2.MessagingParams(dstEid, peer, message, options, false), address(this)
        );
        return fee.nativeFee;
    }

    function _lzSend(uint32 dstEid, bytes memory message, address refund)
        internal
        returns (ILayerZeroEndpointV2.MessagingReceipt memory)
    {
        return _lzSend(dstEid, message, _defaultOptions(), refund);
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

    uint128 internal constant CLAIM_LZ_GAS = 400_000;

    function _defaultOptions() internal pure returns (bytes memory) {
        return OptionsBuilder.lzReceiveOption(CLAIM_LZ_GAS);
    }

    function _optionsWithValue(uint128 value) internal pure returns (bytes memory) {
        return OptionsBuilder.lzReceiveOption(CLAIM_LZ_GAS, value);
    }

    function _lzReceive(
        ILayerZeroEndpointV2.Origin calldata origin,
        bytes32 guid,
        bytes calldata message,
        address executor,
        bytes calldata extraData
    ) internal virtual;
}
