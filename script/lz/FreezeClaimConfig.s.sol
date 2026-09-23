// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafClaimPeer} from "src/lz/LeafClaimPeer.sol";
import {LeafClaimFill} from "src/lz/LeafClaimFill.sol";
import {LeafClaimEscrow} from "src/lz/LeafClaimEscrow.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LeafOrderPolicy} from "src/lz/LeafOrderPolicy.sol";
import {LeafSecurity} from "src/lz/LeafSecurity.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice After WirePeers + SetSecurityStack. Refuses to freeze a wrong peer, endpoint, or stack.
///         PEER is the other OApp. PEER_RPC is that chain's RPC (not this one).
///         HYPERLEAF_DVN must match what SetSecurityStack used (0 if unset).
contract FreezeClaimConfig is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        address expectedPeer = vm.envAddress("PEER");
        string memory id = vm.envString("ASSET");
        address veto = vm.envOr("HYPERLEAF_DVN", address(0));
        AssetCatalog.Listing memory listed = AssetCatalog.requireHere(id);
        LeafClaimPeer box = LeafClaimPeer(payable(oapp));
        uint32 remote = box.remoteEid();
        address ep = address(box.endpoint());
        LeafOrderPolicy.requireClaimPeer(remote, box.peers(remote), id, expectedPeer);
        _requireInstances(listed.sourceChainIdMain, oapp, expectedPeer);

        LeafSecurity.Pathway memory path = LeafSecurity.pathway(block.chainid);
        vm.startBroadcast();
        box.pinLibraries(remote, path.sendLib, path.receiveLib);
        vm.stopBroadcast();
        // After the pin, so getSendLibrary is the OApp selection and not the endpoint default.
        LeafSecurity.requireStack(ep, oapp, block.chainid, remote, veto);

        vm.startBroadcast();
        box.freezeConfig(path.sendLib, path.receiveLib);
        vm.stopBroadcast();
        console2.log("config frozen", oapp);
        console2.log("remoteEid", remote);
        console2.log("peer", expectedPeer);
        console2.log("endpoint", ep);
    }

    /// @dev Local runtime is Fill on a source chain and Escrow on HyperEVM.
    ///      PEER_RPC must be the other chain. eth_chainId is checked before eth_getCode.
    function _requireInstances(uint256 sourceChain, address oapp, address peer) internal {
        bool localEscrow = block.chainid == 999;
        uint256 remoteChain = localEscrow ? sourceChain : 999;
        string memory peerRpc = vm.envString("PEER_RPC");
        uint256 got = LeafOrderPolicy.chainIdFromRpc(vm.rpc(peerRpc, "eth_chainId", "[]"));
        LeafOrderPolicy.requirePeerChain(got, remoteChain);
        LeafOrderPolicy.requireClaimCode(oapp.code, _runtime(!localEscrow, block.chainid));
        bytes memory remoteCode = vm.rpc(peerRpc, "eth_getCode", _codeParams(peer));
        LeafOrderPolicy.requireClaimCode(remoteCode, _runtime(localEscrow, remoteChain));
    }

    function _runtime(bool fill, uint256 chainId) internal returns (bytes memory) {
        address ep = A.endpoint(chainId);
        if (fill) return address(new LeafClaimFill(ep, address(1), address(2))).code;
        return address(new LeafClaimEscrow(ep, address(1), address(2), address(3))).code;
    }

    function _codeParams(address peer) internal returns (string memory) {
        return string.concat("[\"", vm.toString(peer), "\",\"latest\"]");
    }
}
