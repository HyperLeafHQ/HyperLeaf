// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";

/// @notice C1 source after DeployClosed + WirePeers. BATCH=4. Not for L adapters.
contract ConfigureClosedListing is Script {
    function run() external {
        address source = vm.envAddress("SOURCE");
        address harvester = vm.envAddress("HARVESTER");
        address converter = vm.envAddress("CONVERTER");
        address owner = vm.envAddress("OWNER");
        require(harvester != owner && converter != owner, "split keys");

        string memory id = vm.envString("ASSET");
        uint8 batch = uint8(vm.envOr("BATCH", uint256(4)));
        MainnetBatches.requireBatch(id, batch);
        require(batch == MainnetBatches.CLOSED, "not C1 batch");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(a.kind == AssetCatalog.Kind.Closed, "not C1");

        vm.startBroadcast();
        LeafInboundLockbox box = LeafInboundLockbox(source);
        box.setConvertYieldToHype(true);
        box.setHarvester(harvester);
        box.setConverter(converter);
        vm.stopBroadcast();

        console2.log("configured C1", source);
        console2.log("ASSET", a.id);
        console2.log("farm", box.farm());
        console2.log("farmStyle", uint256(box.farmStyle()));
    }
}
