// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";

/// @notice Mainnet L owner ops after DeployAdapter + WirePeers.
///         Batch 3 is **hsWBERA only** on Berachain 80094. No Bepolia.
///         HARVESTER and CONVERTER must not be OWNER.
contract ConfigureMainnetListing is Script {
    function run() external {
        address source = vm.envAddress("SOURCE");
        address harvester = vm.envAddress("HARVESTER");
        address converter = vm.envAddress("CONVERTER");
        address owner = vm.envAddress("OWNER");
        require(harvester != owner && converter != owner, "split keys");

        string memory id = vm.envString("ASSET");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(a.kind == AssetCatalog.Kind.Liquid, "not L");
        require(a.productionEvm, "not production evm");
        require(block.chainid == a.sourceChainIdMain, "wrong source chain");

        vm.startBroadcast();
        LeafOFTAdapter box = LeafOFTAdapter(source);
        box.setConvertYieldToHype(true);
        box.setHarvester(harvester);
        box.setConverter(converter);
        if (keccak256(bytes(a.id)) == keccak256("hswbera") || keccak256(bytes(a.id)) == keccak256("hgsoon")) {
            box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hcbeth")) {
            box.setRateKind(LeafYieldFee.RateKind.ExchangeRate);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hsavax")) {
            box.setRateKind(LeafYieldFee.RateKind.GetPooledAvaxByShares);
            box.setRetainRateYield(true);
        }
        vm.stopBroadcast();

        console2.log("configured", source);
        console2.log("ASSET", a.id);
        console2.log("harvester", harvester);
        console2.log("converter", converter);
    }
}
