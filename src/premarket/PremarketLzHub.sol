// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LeafClaimPeer} from "../lz/LeafClaimPeer.sol";
import {ILayerZeroEndpointV2} from "../lz/interfaces/ILayerZeroEndpointV2.sol";
import {IPremarketDeliveryHub} from "./IPremarketDeliveryHub.sol";
import {PremarketOriginLock} from "./PremarketOriginLock.sol";

interface IFactoryCredit {
    function onDeliveryCredit(bytes32 seriesId, uint256 amount) external;
}

/// @notice LZ hub for official-token delivery. Deploy one on the origin chain
///         (`isOrigin=true`, wired to PremarketOriginLock) and one on HyperEVM
///         (`isOrigin=false`, set as Factory.lockbox).
contract PremarketLzHub is LeafClaimPeer, IPremarketDeliveryHub {
    uint8 public constant OP_CREDIT = 1;
    uint8 public constant OP_RELEASE = 2;

    bool public immutable isOrigin;
    address public lock;
    address public factory;

    error AlreadySet();
    error WrongSide();
    error NotLock();
    error NotFactory();
    error BadOp();
    error Zero();

    constructor(address endpoint_, address owner_, address guardian_, bool isOrigin_)
        LeafClaimPeer(endpoint_, owner_, guardian_)
    {
        isOrigin = isOrigin_;
    }

    function setLock(address l) external onlyOwner {
        if (!isOrigin) revert WrongSide();
        if (lock != address(0)) revert AlreadySet();
        if (l == address(0)) revert Zero();
        lock = l;
    }

    function setFactory(address f) external onlyOwner {
        if (isOrigin) revert WrongSide();
        if (factory != address(0)) revert AlreadySet();
        if (f == address(0)) revert Zero();
        factory = f;
    }

    function notifyCredit(bytes32 seriesId, uint256 amount, address refundTo) external payable whenNotPaused {
        if (!isOrigin) revert WrongSide();
        if (msg.sender != lock) revert NotLock();
        if (seriesId == bytes32(0) || amount == 0 || refundTo == address(0)) revert Zero();
        _lzSend(remoteEid, abi.encode(OP_CREDIT, seriesId, address(0), amount), refundTo);
    }

    function notifyRelease(bytes32 seriesId, address to, uint256 amount, address refundTo)
        external
        payable
        whenNotPaused
    {
        if (isOrigin) revert WrongSide();
        if (msg.sender != factory) revert NotFactory();
        if (seriesId == bytes32(0) || to == address(0) || amount == 0 || refundTo == address(0)) revert Zero();
        _lzSend(remoteEid, abi.encode(OP_RELEASE, seriesId, to, amount), refundTo);
    }

    function _lzReceive(ILayerZeroEndpointV2.Origin calldata, bytes32, bytes calldata message, address, bytes calldata)
        internal
        override
        whenNotPaused
    {
        (uint8 op, bytes32 seriesId, address to, uint256 amount) =
            abi.decode(message, (uint8, bytes32, address, uint256));
        if (op == OP_CREDIT) {
            if (isOrigin) revert WrongSide();
            IFactoryCredit(factory).onDeliveryCredit(seriesId, amount);
        } else if (op == OP_RELEASE) {
            if (!isOrigin) revert WrongSide();
            PremarketOriginLock(lock).release(seriesId, to, amount);
        } else {
            revert BadOp();
        }
    }
}
