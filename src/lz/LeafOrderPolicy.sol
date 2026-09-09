// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HypeAddresses as H} from "./HypeAddresses.sol";

/// @notice hORDER pins. Arbitrum only. Never the Ethereum ERC-20. Never CREATE2 twin.
library LeafOrderPolicy {
    address internal constant ORDER_OFT = H.ORDER_OFT;
    address internal constant ORDERLY_PROXY = H.ORDERLY_PROXY;
    address internal constant ORDER_ETH = 0xABD4C63d2616A5201454168269031355f4764337;
    address internal constant USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    bytes4 internal constant STAKE_ORDER = 0x413aaa60; // stakeOrder(uint256)
    bytes4 internal constant SEND_REQUEST = 0xcec09c0d; // sendUserRequest(uint256,uint8)

    uint8 internal constant TYPE_UNSTAKE_2 = 2;
    uint8 internal constant TYPE_UNSTAKE_3 = 3;
    uint8 internal constant TYPE_UNSTAKE_4 = 4;
    uint8 internal constant TYPE_HARVEST_USDC = 10;
    uint8 internal constant TYPE_OCCUPANCY = 17;

    error WrongInner();
    error WrongChain();

    function requireArbOrder(address inner, uint256 chainId) internal pure {
        if (chainId != 42161) revert WrongChain();
        if (inner != ORDER_OFT || inner == ORDER_ETH) revert WrongInner();
    }

    function isPublicRequestType(uint8 payloadType) internal pure returns (bool) {
        return payloadType == TYPE_HARVEST_USDC || payloadType == TYPE_OCCUPANCY;
    }

    function isUnstakeType(uint8 payloadType) internal pure returns (bool) {
        return payloadType == TYPE_UNSTAKE_2 || payloadType == TYPE_UNSTAKE_3 || payloadType == TYPE_UNSTAKE_4;
    }
}
