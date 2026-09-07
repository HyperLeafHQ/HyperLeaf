// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";

/// @notice Source-chain owner ops after DeployTestnetSource + WirePeers.
///         HARVESTER and CONVERTER must not be OWNER.
contract ConfigureTestnetListing is Script {
    bytes4 internal constant QUID_REWARDS = 0x9a99b4f0;

    function run() external {
        address source = vm.envAddress("SOURCE");
        address harvester = vm.envAddress("HARVESTER");
        address converter = vm.envAddress("CONVERTER");
        address owner = vm.envAddress("OWNER");
        require(harvester != owner && converter != owner, "split keys");

        string memory id = vm.envOr("ASSET", string("hxsquid"));
        AssetCatalog.Listing memory a = AssetCatalog.get(id);

        vm.startBroadcast();
        LeafOFTAdapter box = LeafOFTAdapter(source);
        box.setConvertYieldToHype(true);
        box.setHarvester(harvester);
        box.setConverter(converter);
        if (keccak256(bytes(a.id)) == keccak256("hxsquid")) {
            box.setRewardsSelector(QUID_REWARDS);
        }
        vm.stopBroadcast();

        console2.log("configured", source);
        console2.log("harvester", harvester);
        console2.log("converter", converter);
        console2.log("ASSET", a.id);
    }
}
