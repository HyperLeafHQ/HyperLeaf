// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

contract DeployClosed is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = vm.envOr("DEPOSIT_CAP", uint256(1_000e18));
        uint256 chainId = block.chainid;

        vm.startBroadcast();
        if (chainId == 56 || chainId == 97 || chainId == 42161) {
            string memory id = vm.envOr("ASSET", string(""));
            if (bytes(id).length != 0) {
                uint8 batch = uint8(vm.envOr("BATCH", uint256(4)));
                MainnetBatches.requireBatch(id, batch);
                require(batch == MainnetBatches.CLOSED, "not C1 batch");
            }
            address inner = vm.envAddress("INNER_TOKEN");
            if (chainId == 56 || chainId == 42161) {
                require(bytes(id).length != 0, "ASSET required on mainnet");
                require(inner == AssetCatalog.get(id).innerMainnet, "inner != catalog");
            }
            address endpoint = A.endpoint(chainId);
            LeafInboundLockbox box =
                new LeafInboundLockbox(inner, endpoint, owner, guardian, feeRecipient, cap);
            console2.log("ASSET", id);
            console2.log("LeafInboundLockbox", address(box));
        } else if (chainId == 999 || chainId == 998) {
            string memory id = vm.envOr("ASSET", string(""));
            string memory name;
            string memory symbol;
            uint32 lockSeconds;
            if (bytes(id).length != 0) {
                AssetCatalog.Listing memory a = AssetCatalog.get(id);
                require(a.kind == AssetCatalog.Kind.Closed, "not C1");
                name = a.name;
                symbol = a.symbol;
                lockSeconds = a.lockSeconds;
            } else {
                name = vm.envOr("OFT_NAME", string("Hyperliquid BLUAI 4Year"));
                symbol = vm.envOr("OFT_SYMBOL", string("BLUAI4Y"));
                lockSeconds = uint32(vm.envOr("LOCK_SECONDS", uint256(A.LOCK_4Y)));
            }
            address endpoint = chainId == 999 ? A.ENDPOINT_HYPEREVM : A.ENDPOINT_HYPEREVM_TESTNET;
            LeafClosedOFT oft = new LeafClosedOFT(name, symbol, lockSeconds, endpoint, owner, guardian);
            console2.log("ASSET", id);
            console2.log("LeafClosedOFT", address(oft));
        } else if (chainId == 84532) {
            address inner = vm.envAddress("INNER_TOKEN");
            LeafInboundLockbox box =
                new LeafInboundLockbox(inner, A.endpoint(chainId), owner, guardian, feeRecipient, cap);
            console2.log("LeafInboundLockbox", address(box));
        } else {
            revert("unsupported chain");
        }
        vm.stopBroadcast();
    }
}
