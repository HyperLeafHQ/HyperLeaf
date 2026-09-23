// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LeafOrderPolicy} from "src/lz/LeafOrderPolicy.sol";
import {LeafSecurity} from "src/lz/LeafSecurity.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {LeafClaimFill} from "src/lz/LeafClaimFill.sol";
import {LeafClaimEscrow} from "src/lz/LeafClaimEscrow.sol";

contract MockCfgEndpoint {
    mapping(bytes32 => bytes) public stored;
    address public sendLib;
    address public recvLib;
    bool public sendDefault;
    bool public recvDefault;

    function set(address lib, uint32 eid, uint32 typ, bytes memory cfg) external {
        stored[keccak256(abi.encode(lib, eid, typ))] = cfg;
    }

    function setLibs(address send, address recv, bool sendIsDefault, bool recvIsDefault) external {
        sendLib = send;
        recvLib = recv;
        sendDefault = sendIsDefault;
        recvDefault = recvIsDefault;
    }

    function getConfig(address, address lib, uint32 eid, uint32 typ) external view returns (bytes memory) {
        return stored[keccak256(abi.encode(lib, eid, typ))];
    }

    function getSendLibrary(address, uint32) external view returns (address) {
        return sendLib;
    }

    function isDefaultSendLibrary(address, uint32) external view returns (bool) {
        return sendDefault;
    }

    function getReceiveLibrary(address, uint32) external view returns (address, bool) {
        return (recvLib, recvDefault);
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
        vm.expectRevert(LeafOrderPolicy.WrongInner.selector);
        this._escrow("horder", address(0xBEEF), address(0x1), keccak256("horder"), address(0));
        vm.chainId(8453);
        LeafOrderPolicy.requireEscrowDest("hkaito", address(0xBEEF), address(0x1), bytes32(0), address(0));
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
        address canonical = A.endpoint(42161);
        vm.etch(canonical, type(MockCfgEndpoint).runtimeCode);
        MockCfgEndpoint ep = MockCfgEndpoint(canonical);
        uint32 remote = A.EID_HYPEREVM;
        LeafSecurity.Pathway memory p = LeafSecurity.pathway(42161);
        uint64 sendConf = A.confirmationsForEid(A.eidForChainId(42161));
        uint64 recvConf = A.confirmationsForEid(remote);
        ep.set(p.sendLib, remote, A.CONFIG_TYPE_ULN, LeafSecurity.ulnConfig(sendConf, address(0), p.optionalDvns));
        ep.set(p.receiveLib, remote, A.CONFIG_TYPE_ULN, LeafSecurity.ulnConfig(recvConf, address(0), p.optionalDvns));
        ep.set(p.sendLib, remote, A.CONFIG_TYPE_EXECUTOR, LeafSecurity.executorConfig(p.executor));
        ep.setLibs(p.sendLib, p.receiveLib, false, false);
        LeafSecurity.requireStack(canonical, address(this), 42161, remote, address(0));
        ep.set(p.sendLib, remote, A.CONFIG_TYPE_ULN, hex"00");
        vm.expectRevert(LeafSecurity.StackMismatch.selector);
        this._stack(canonical, 42161, remote);
    }

    function testRejectsNonCanonicalEndpoint() public {
        assertTrue(A.endpoint(999) != A.endpoint(42161));
        vm.expectRevert(LeafSecurity.BadEndpoint.selector);
        this._stack(A.endpoint(999), 42161, A.EID_HYPEREVM);
        vm.expectRevert(LeafSecurity.BadEndpoint.selector);
        this._stack(address(0xBEEF), 999, 30110);
    }

    function testRejectsDefaultOrWrongLibrary() public {
        address canonical = A.endpoint(42161);
        vm.etch(canonical, type(MockCfgEndpoint).runtimeCode);
        MockCfgEndpoint ep = MockCfgEndpoint(canonical);
        LeafSecurity.Pathway memory p = LeafSecurity.pathway(42161);
        ep.setLibs(p.sendLib, p.receiveLib, true, false);
        vm.expectRevert(LeafSecurity.BadLibrary.selector);
        this._stack(canonical, 42161, A.EID_HYPEREVM);
        ep.setLibs(address(0xBEEF), p.receiveLib, false, false);
        vm.expectRevert(LeafSecurity.BadLibrary.selector);
        this._stack(canonical, 42161, A.EID_HYPEREVM);
    }

    function testPeerRpcChainId() public {
        assertEq(LeafOrderPolicy.chainIdFromRpc(hex"03e7"), 999);
        assertEq(LeafOrderPolicy.chainIdFromRpc(hex"a4b1"), 42161);
        assertEq(LeafOrderPolicy.chainIdFromRpc(hex"01"), 1);
        LeafOrderPolicy.requirePeerChain(42161, 42161);
        vm.expectRevert(LeafOrderPolicy.BadMarket.selector);
        this._rpcChain(hex"");
        vm.expectRevert(LeafOrderPolicy.BadMarket.selector);
        this._peerChain(999, 42161);
    }

    function testClaimCodeMatchesSideNotOwner() public {
        address hevm = A.endpoint(999);
        LeafClaimEscrow a = new LeafClaimEscrow(hevm, address(1), address(2), address(3));
        LeafClaimEscrow b = new LeafClaimEscrow(hevm, address(4), address(5), address(6));
        LeafOrderPolicy.requireClaimCode(address(a).code, address(b).code);
        LeafClaimFill fill = new LeafClaimFill(A.endpoint(42161), address(1), address(2));
        LeafClaimFill fillOtherOwner = new LeafClaimFill(A.endpoint(42161), address(9), address(8));
        LeafOrderPolicy.requireClaimCode(address(fill).code, address(fillOtherOwner).code);
        vm.expectRevert(LeafOrderPolicy.BadMarket.selector);
        this._code(address(a).code, address(fill).code);
        vm.expectRevert(LeafOrderPolicy.BadMarket.selector);
        this._code(hex"", address(b).code);
        LeafClaimEscrow wrongEp = new LeafClaimEscrow(A.endpoint(42161), address(1), address(2), address(3));
        vm.expectRevert(LeafOrderPolicy.BadMarket.selector);
        this._code(address(a).code, address(wrongEp).code);
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

    function _code(bytes calldata actual, bytes calldata expected) external pure {
        LeafOrderPolicy.requireClaimCode(actual, expected);
    }

    function _rpcChain(bytes calldata raw) external pure returns (uint256) {
        return LeafOrderPolicy.chainIdFromRpc(raw);
    }

    function _peerChain(uint256 actual, uint256 expected) external pure {
        LeafOrderPolicy.requirePeerChain(actual, expected);
    }
}
