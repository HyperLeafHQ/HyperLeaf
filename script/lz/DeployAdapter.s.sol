// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

import {MainnetBatches} from "src/lz/MainnetBatches.sol";

/// @notice Mainnet L source. BATCH=1|2|3. Never canary, never a mock inner.
///         Broadcast on the listing's sourceChainIdMain.
contract DeployAdapter is Script {
    function run() external {
        string memory id = vm.envString("ASSET");
        uint8 batch = uint8(vm.envOr("BATCH", uint256(1)));
        MainnetBatches.requireBatch(id, batch);
        require(batch != MainnetBatches.CANARY, "use DeployCanarySource");
        require(batch != MainnetBatches.CLOSED, "C1: DeployClosed");
        require(batch != MainnetBatches.SOLANA_L, "Solana: not LeafOFTAdapter");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(a.kind == AssetCatalog.Kind.Liquid, "not L");
        require(a.productionEvm, "not production evm");
        require(block.chainid == a.sourceChainIdMain, "wrong source chain");
        require(a.innerMainnet != address(0), "no inner");
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = vm.envOr("DEPOSIT_CAP", a.defaultCap);
        address endpoint = A.endpoint(block.chainid);
        vm.startBroadcast();
        LeafOFTAdapter adapter =
            new LeafOFTAdapter(a.innerMainnet, endpoint, owner, guardian, feeRecipient, cap);
        console2.log("ASSET", id);
        console2.log("inner", a.innerMainnet);
        console2.log("LeafOFTAdapter", address(adapter));
        vm.stopBroadcast();
    }
}
