// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HypeAddresses as H} from "./HypeAddresses.sol";
import {AssetCatalog} from "./AssetCatalog.sol";
import {LayerZeroAddresses as LZ} from "./LayerZeroAddresses.sol";

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
    error BadMarket();

    address internal constant BLUAI_ESCROW = 0x367FB8667919dD94874C0a48156C94E0D254d43c;

    function requireArbOrder(address inner, uint256 chainId) internal pure {
        if (chainId != 42161) revert WrongChain();
        if (inner != ORDER_OFT || inner == ORDER_ETH) revert WrongInner();
    }

    function requireFillSource(string memory id, address want) internal view {
        if (bytes(id).length != 0) {
            AssetCatalog.Listing memory a = AssetCatalog.requireHere(id);
            if (want != a.innerMainnet) revert WrongInner();
        }
        if (want == ORDER_OFT || want == ORDER_ETH) {
            if (keccak256(bytes(id)) != keccak256("horder")) revert BadMarket();
            requireArbOrder(want, block.chainid);
        }
    }

    function requireEscrowDest(string memory id, address want, address leaf, bytes32 rewardId, address nestVault)
        internal
        view
    {
        if (want != ORDER_OFT && want != ORDER_ETH) return;
        if (want != ORDER_OFT) revert WrongInner();
        if (keccak256(bytes(id)) != keccak256("horder")) revert BadMarket();
        if (rewardId != keccak256("horder")) revert BadMarket();
        if (nestVault != address(0)) revert BadMarket();
        if (leaf == BLUAI_ESCROW) revert BadMarket();
        AssetCatalog.requireHere(id);
    }

    function requireClaimPeer(uint32 remoteEid, bytes32 peer, string memory id, address expected) internal view {
        if (keccak256(bytes(id)) == keccak256("horder")) {
            uint32 expect = block.chainid == 999 ? uint32(30110) : LZ.EID_HYPEREVM;
            if (remoteEid != expect) revert BadMarket();
        } else if (remoteEid == 0) {
            revert BadMarket();
        }
        if (expected == address(0) || peer != bytes32(uint256(uint160(expected)))) revert BadMarket();
    }

    /// @dev Runtime bytecode identity. Empty, wrong side, or a different endpoint immutable fails.
    ///      Owners and storage do not affect this. The peer lives on the other chain, so the
    ///      caller must pass `eth_getCode` from that chain, not local extcodesize.
    function requireClaimCode(bytes memory actual, bytes memory expected) internal pure {
        if (expected.length == 0 || keccak256(actual) != keccak256(expected)) revert BadMarket();
    }

    function isPublicRequestType(uint8 payloadType) internal pure returns (bool) {
        return payloadType == TYPE_HARVEST_USDC || payloadType == TYPE_OCCUPANCY;
    }

    function isUnstakeType(uint8 payloadType) internal pure returns (bool) {
        return payloadType == TYPE_UNSTAKE_2 || payloadType == TYPE_UNSTAKE_3 || payloadType == TYPE_UNSTAKE_4;
    }
}
