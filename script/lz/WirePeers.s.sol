// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

contract WirePeers is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        address peer = vm.envAddress("PEER");
        uint256 chainId = block.chainid;
        uint32 remoteEid;
        if (chainId == 8453) remoteEid = A.EID_HYPEREVM;
        else if (chainId == 999) remoteEid = A.EID_BASE;
        else if (chainId == 84532) remoteEid = A.EID_HYPEREVM_TESTNET;
        else if (chainId == 998) remoteEid = A.EID_BASE_SEPOLIA;
        else revert("unsupported chain");
        vm.startBroadcast();
        LeafOApp(oapp).setPeer(remoteEid, peer);
        vm.stopBroadcast();
        console2.log("peer set", oapp, remoteEid, peer);
    }
}
