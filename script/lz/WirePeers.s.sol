// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice Set the LZ peer. HyperEVM must pass ASSET or REMOTE_EID (do not default Base for BSC/Bera/Arb).
contract WirePeers is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        address peer = vm.envAddress("PEER");
        uint32 remoteEid = _remoteEid();
        vm.startBroadcast();
        LeafOApp(oapp).setPeer(remoteEid, peer);
        vm.stopBroadcast();
        console2.log("peer set", oapp);
        console2.log("remoteEid", remoteEid);
        console2.log("peer", peer);
    }

    function _remoteEid() internal view returns (uint32) {
        uint256 explicitEid = vm.envOr("REMOTE_EID", uint256(0));
        if (explicitEid != 0) return uint32(explicitEid);
        string memory id = vm.envOr("ASSET", string(""));
        if (bytes(id).length != 0 && block.chainid == 999) {
            return AssetCatalog.get(id).sourceEidMain;
        }
        return _defaultRemoteEid(block.chainid);
    }

    function _defaultRemoteEid(uint256 chainId) internal pure returns (uint32) {
        if (chainId == 8453 || chainId == 56 || chainId == 80094 || chainId == 1 || chainId == 42161 || chainId == 43114)
        {
            return A.EID_HYPEREVM;
        }
        if (chainId == 999) revert("set ASSET or REMOTE_EID on HyperEVM");
        if (chainId == 84532) return A.EID_HYPEREVM_TESTNET;
        if (chainId == 998) return A.EID_BASE_SEPOLIA;
        if (chainId == 97) return A.EID_HYPEREVM_TESTNET;
        revert("unsupported chain, set REMOTE_EID");
    }
}
