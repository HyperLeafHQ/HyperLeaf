// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafClaimPeer} from "src/lz/LeafClaimPeer.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LeafOrderPolicy} from "src/lz/LeafOrderPolicy.sol";
import {LeafSecurity} from "src/lz/LeafSecurity.sol";

/// @notice After WirePeers + SetSecurityStack. Refuses to freeze a wrong peer or stack.
///         PEER is the other OApp. HYPERLEAF_DVN must match what SetSecurityStack used (0 if unset).
contract FreezeClaimConfig is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        address expectedPeer = vm.envAddress("PEER");
        string memory id = vm.envString("ASSET");
        address veto = vm.envOr("HYPERLEAF_DVN", address(0));
        AssetCatalog.requireHere(id);
        LeafClaimPeer box = LeafClaimPeer(payable(oapp));
        uint32 remote = box.remoteEid();
        LeafOrderPolicy.requireClaimPeer(remote, box.peers(remote), id, expectedPeer);
        LeafSecurity.requireStack(address(box.endpoint()), oapp, block.chainid, remote, veto);

        vm.startBroadcast();
        box.freezeConfig();
        vm.stopBroadcast();
        console2.log("config frozen", oapp);
        console2.log("remoteEid", remote);
        console2.log("peer", expectedPeer);
    }
}
