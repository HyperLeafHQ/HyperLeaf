// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Minimal LayerZero V2 Endpoint surface used by Leaf OApps.
interface ILayerZeroEndpointV2 {
    struct MessagingParams {
        uint32 dstEid;
        bytes32 receiver;
        bytes message;
        bytes options;
        bool payInLzToken;
    }

    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct Origin {
        uint32 srcEid;
        bytes32 sender;
        uint64 nonce;
    }

    function eid() external view returns (uint32);

    function send(MessagingParams calldata _params, address _refundAddress)
        external
        payable
        returns (MessagingReceipt memory);

    function quote(MessagingParams calldata _params, address _sender)
        external
        view
        returns (MessagingFee memory);

    function setDelegate(address _delegate) external;

    function setConfig(address _oapp, address _lib, SetConfigParam[] calldata _params) external;

    function getConfig(address _oapp, address _lib, uint32 _eid, uint32 _configType)
        external
        view
        returns (bytes memory);

    function skip(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce) external;
}

struct SetConfigParam {
    uint32 eid;
    uint32 configType;
    bytes config;
}
