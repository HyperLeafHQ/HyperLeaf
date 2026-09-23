// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafClaimPeer} from "src/lz/LeafClaimPeer.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice After WirePeers + SetSecurityStack + readback. Locks endpoint config.
///         hORDER: HyperEVM remote must be 30110; Arb remote must be HyperEVM.
contract FreezeClaimConfig is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        string memory id = vm.envString("ASSET");
        AssetCatalog.requireHere(id);
        LeafClaimPeer peer = LeafClaimPeer(payable(oapp));
        uint32 remote = peer.remoteEid();
        if (keccak256(bytes(id)) == keccak256("horder")) {
            uint32 expect = block.chainid == 999 ? uint32(30110) : A.EID_HYPEREVM;
            require(remote == expect, "horder remote eid");
        } else {
            require(remote != 0, "no peer");
        }

        vm.startBroadcast();
        peer.freezeConfig();
        vm.stopBroadcast();
        console2.log("config frozen", oapp);
        console2.log("remoteEid", remote);
    }
}
