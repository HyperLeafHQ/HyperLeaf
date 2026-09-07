// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice HyperEVM mainnet (999) dest OFT. ASSET=hgsoon|hswbera|…
contract DeployOFT is Script {
    function run() external {
        string memory id = vm.envString("ASSET");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(block.chainid == 999, "HyperEVM 999");
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        vm.startBroadcast();
        LeafOFT oft = new LeafOFT(a.name, a.symbol, A.ENDPOINT_HYPEREVM, owner, guardian);
        console2.log("ASSET", id);
        console2.log("LeafOFT", address(oft));
        vm.stopBroadcast();
    }
}
