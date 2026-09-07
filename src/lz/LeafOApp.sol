// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "./interfaces/ILayerZeroEndpointV2.sol";
import {OptionsBuilder} from "./OptionsBuilder.sol";
import {LayerZeroAddresses} from "./LayerZeroAddresses.sol";

abstract contract LeafOApp is Ownable2Step, Pausable {
    ILayerZeroEndpointV2 public immutable endpoint;
    address public guardian;
    mapping(uint32 eid => bytes32 peer) public peers;

    event PeerSet(uint32 indexed eid, bytes32 peer);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);

    error ZeroAddress();
    error OnlyEndpoint();
    error OnlyPeer();
    error NoPeer();
    error NotGuardian();

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
        peers[eid] = peer;
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

    function setEndpointConfig(address lib, SetConfigParam[] calldata params) external onlyOwner {
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

    /// @notice Native fee for `sendTo(dstEid, to, amount)` with default lzReceive gas.
    function quoteSend(uint32 dstEid, address to, uint256 amount) external view returns (uint256 nativeFee) {
        bytes memory payload = abi.encode(bytes32(uint256(uint160(to))), amount);
        (nativeFee,) = quote(dstEid, payload, _defaultOptions(), false);
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

    function _lzReceive(
        ILayerZeroEndpointV2.Origin calldata origin,
        bytes32 guid,
        bytes calldata message,
        address executor,
        bytes calldata extraData
    ) internal virtual;
}
