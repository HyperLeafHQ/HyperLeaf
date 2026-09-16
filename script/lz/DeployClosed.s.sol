// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {LeafOrderPolicy} from "src/lz/LeafOrderPolicy.sol";

contract DeployClosed is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        // 0 = no HyperLeaf intake cap. Do not default to 1_000e18.
        uint256 cap;
        try vm.envUint("DEPOSIT_CAP") returns (uint256 explicitCap) {
            cap = explicitCap;
        } catch {
            string memory asset = vm.envOr("ASSET", string(""));
            cap = bytes(asset).length == 0 ? 0 : AssetCatalog.get(asset).defaultCap;
        }
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
                AssetCatalog.Listing memory listing = AssetCatalog.get(id);
                require(block.chainid == listing.sourceChainIdMain, "wrong source chain");
                require(inner == listing.innerMainnet, "inner != catalog");
                if (keccak256(bytes(listing.id)) == keccak256("horder")) {
                    LeafOrderPolicy.requireArbOrder(inner, block.chainid);
                }
            }
            address endpoint = A.endpoint(chainId);
            LeafInboundLockbox box =
                new LeafInboundLockbox(inner, endpoint, owner, guardian, feeRecipient, cap);
            console2.log("ASSET", id);
            console2.log("depositCap", cap);
            console2.log("LeafInboundLockbox", address(box));
        } else if (chainId == 999 || chainId == 998) {
            string memory id = vm.envOr("ASSET", string(""));
            require(bytes(id).length != 0, "ASSET required on dest");
            AssetCatalog.Listing memory a = AssetCatalog.get(id);
            require(a.kind == AssetCatalog.Kind.Closed, "not C1");
            MainnetBatches.requireBatch(id, MainnetBatches.CLOSED);
            string memory name = a.name;
            string memory symbol = a.symbol;
            uint32 lockSeconds = a.lockSeconds;
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
