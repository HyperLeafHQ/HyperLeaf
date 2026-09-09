// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice HyperEVM mainnet dest OFT for the toy canary. Separate from real listings.
contract DeployCanaryDest is Script {
    function run() external {
        require(block.chainid == 999, "HyperEVM 999");
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        AssetCatalog.Listing memory a = AssetCatalog.get("hcanary");

        vm.startBroadcast();
        LeafOFT oft = new LeafOFT(a.name, a.symbol, A.ENDPOINT_HYPEREVM, owner, guardian);
        vm.stopBroadcast();

        console2.log("ASSET hcanary");
        console2.log("LeafOFT", address(oft));
    }
}
