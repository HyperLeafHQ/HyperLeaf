// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";

/// @notice HyperEVM peer for a Solana PDA (32 bytes). Do not use WirePeers(address)
///         — that left-pads a 20-byte EVM address and will brick the pathway.
contract WireSolanaPeer is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        bytes32 peer = vm.envBytes32("PEER");
        require(peer != bytes32(0), "PEER");
        require(bytes12(peer) != bytes12(0), "PEER looks like an EVM address");
        string memory id = vm.envOr("ASSET", string("hjitosol"));
        uint32 remoteEid = AssetCatalog.get(id).sourceEidMain;
        require(remoteEid == 30168, "not Solana");
        require(block.chainid == 999, "HyperEVM 999");

        vm.startBroadcast();
        LeafOApp(oapp).setPeer(remoteEid, peer);
        vm.stopBroadcast();

        console2.log("OAPP", oapp);
        console2.log("remoteEid", remoteEid);
        console2.logBytes32(peer);
    }
}
