// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LeafOrderPolicy} from "src/lz/LeafOrderPolicy.sol";
import {LeafSecurity} from "src/lz/LeafSecurity.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

contract MockCfgEndpoint {
    mapping(bytes32 => bytes) public stored;

    function set(address lib, uint32 eid, uint32 typ, bytes memory cfg) external {
        stored[keccak256(abi.encode(lib, eid, typ))] = cfg;
    }

    function getConfig(address, address lib, uint32 eid, uint32 typ) external view returns (bytes memory) {
        return stored[keccak256(abi.encode(lib, eid, typ))];
    }
}

contract LeafClaimFreezeGuardTest is Test {
    address constant OFT = 0x4E200fE2f3eFb977d5fd9c430A41531FB04d97B8;
    address constant ETH_ORDER = 0xABD4C63d2616A5201454168269031355f4764337;
    address constant BLUAI = 0x367FB8667919dD94874C0a48156C94E0D254d43c;

    function testPinnedRemoteIgnoresOtherChains() public {
        vm.chainId(42161);
        assertEq(AssetCatalog.pinnedRemote("horder"), A.EID_HYPEREVM);
        vm.chainId(999);
        assertEq(AssetCatalog.pinnedRemote("horder"), 30110);
        vm.chainId(8453);
        vm.expectRevert(AssetCatalog.WrongSourceChain.selector);
        this._pinned("horder");
    }

    function testFillSourceRejectsEthOrderAndWrongChain() public {
        vm.chainId(42161);
        LeafOrderPolicy.requireFillSource("horder", OFT);
        vm.expectRevert(LeafOrderPolicy.WrongInner.selector);
        this._fill("horder", ETH_ORDER);
        vm.expectRevert(LeafOrderPolicy.WrongInner.selector);
        this._fill("horder", address(0xBEEF));
        vm.chainId(56);
        vm.expectRevert(AssetCatalog.WrongSourceChain.selector);
        this._fill("horder", OFT);
    }

    function testEscrowDestRejectsEthOrderAndBluai() public {
        vm.chainId(999);
        LeafOrderPolicy.requireEscrowDest("horder", OFT, address(0x1), keccak256("horder"), address(0));
        vm.expectRevert(LeafOrderPolicy.WrongInner.selector);
        this._escrow("horder", ETH_ORDER, address(0x1), keccak256("horder"), address(0));
        vm.expectRevert(LeafOrderPolicy.BadMarket.selector);
        this._escrow("horder", OFT, BLUAI, keccak256("horder"), address(0));
    }

    function testClaimPeerEidAndAddress() public {
        address peer = address(0xF111);
        bytes32 peerB = bytes32(uint256(uint160(peer)));
        vm.chainId(42161);
        LeafOrderPolicy.requireClaimPeer(A.EID_HYPEREVM, peerB, "horder", peer);
        vm.expectRevert(LeafOrderPolicy.BadMarket.selector);
        this._peer(30110, peerB, "horder", peer);
        vm.expectRevert(LeafOrderPolicy.BadMarket.selector);
        this._peer(A.EID_HYPEREVM, peerB, "horder", address(0xF222));
        vm.chainId(999);
        LeafOrderPolicy.requireClaimPeer(30110, peerB, "horder", peer);
        vm.expectRevert(LeafOrderPolicy.BadMarket.selector);
        this._peer(A.EID_HYPEREVM, peerB, "horder", peer);
    }

    function testStackReadback() public {
        MockCfgEndpoint ep = new MockCfgEndpoint();
        uint32 remote = A.EID_HYPEREVM;
        LeafSecurity.Pathway memory p = LeafSecurity.pathway(42161);
        uint64 sendConf = A.confirmationsForEid(A.eidForChainId(42161));
        uint64 recvConf = A.confirmationsForEid(remote);
        ep.set(p.sendLib, remote, A.CONFIG_TYPE_ULN, LeafSecurity.ulnConfig(sendConf, address(0), p.optionalDvns));
        ep.set(p.receiveLib, remote, A.CONFIG_TYPE_ULN, LeafSecurity.ulnConfig(recvConf, address(0), p.optionalDvns));
        ep.set(p.sendLib, remote, A.CONFIG_TYPE_EXECUTOR, LeafSecurity.executorConfig(p.executor));
        LeafSecurity.requireStack(address(ep), address(this), 42161, remote, address(0));
        ep.set(p.sendLib, remote, A.CONFIG_TYPE_ULN, hex"00");
        vm.expectRevert(LeafSecurity.StackMismatch.selector);
        this._stack(address(ep), 42161, remote);
    }

    function _pinned(string calldata id) external view returns (uint32) {
        return AssetCatalog.pinnedRemote(id);
    }

    function _fill(string calldata id, address want) external view {
        LeafOrderPolicy.requireFillSource(id, want);
    }

    function _escrow(string calldata id, address want, address leaf, bytes32 rewardId, address nest) external view {
        LeafOrderPolicy.requireEscrowDest(id, want, leaf, rewardId, nest);
    }

    function _peer(uint32 eid, bytes32 peer, string calldata id, address expected) external view {
        LeafOrderPolicy.requireClaimPeer(eid, peer, id, expected);
    }

    function _stack(address ep, uint256 chainId, uint32 remote) external view {
        LeafSecurity.requireStack(ep, address(this), chainId, remote, address(0));
    }
}
