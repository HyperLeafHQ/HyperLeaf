// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice Set the LZ peer. Pass OAPP (local) + PEER (remote address) + optional REMOTE_EID.
contract WirePeers is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        address peer = vm.envAddress("PEER");
        uint32 remoteEid = uint32(vm.envOr("REMOTE_EID", uint256(_defaultRemoteEid(block.chainid))));
        vm.startBroadcast();
        LeafOApp(oapp).setPeer(remoteEid, peer);
        vm.stopBroadcast();
        console2.log("peer set", oapp);
        console2.log("remoteEid", remoteEid);
        console2.log("peer", peer);
    }

    function _defaultRemoteEid(uint256 chainId) internal pure returns (uint32) {
        if (chainId == 8453) return A.EID_HYPEREVM;
        if (chainId == 999) return A.EID_BASE;
        if (chainId == 56) return A.EID_HYPEREVM;
        if (chainId == 84532) return A.EID_HYPEREVM_TESTNET;
        if (chainId == 998) return A.EID_BASE_SEPOLIA;
        if (chainId == 97) return A.EID_HYPEREVM_TESTNET;
        if (chainId == 80094) return A.EID_HYPEREVM;
        revert("unsupported chain, set REMOTE_EID");
    }
}
