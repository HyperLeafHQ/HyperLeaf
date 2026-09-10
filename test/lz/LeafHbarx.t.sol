// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafHts} from "src/lz/LeafHts.sol";
import {LeafHbarxPolicy} from "src/lz/LeafHbarxPolicy.sol";
import {LeafLbtcPolicy} from "src/lz/LeafLbtcPolicy.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {LeafSecurity} from "src/lz/LeafSecurity.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockHtsPrecompile {
    int64 public code;
    mapping(address => mapping(address => bool)) public associated;

    function setCode(int64 c) external {
        code = c;
    }

    function associateToken(address account, address token) external returns (int64) {
        int64 c = code == 0 ? int64(22) : code;
        if (c == 22 || c == 194) associated[account][token] = true;
        return c;
    }
}

contract MockEndpointHbarx is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30316;
    }
    function send(MessagingParams calldata p, address) external payable returns (MessagingReceipt memory r) {
        r.guid = keccak256(abi.encode(p, block.number));
        r.nonce = 1;
        r.fee = MessagingFee(msg.value, 0);
    }
    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee(0.01 ether, 0);
    }
    function setDelegate(address) external {}
    function setConfig(address, address, SetConfigParam[] calldata) external {}
    function getConfig(address, address, uint32, uint32) external pure returns (bytes memory) {
        return "";
    }
    function skip(address, uint32, bytes32, uint64) external {}
}

contract LeafHbarxTest is PegReady {
    MockEndpointHbarx ep;
    MockERC20 inner;
    MockHtsPrecompile hts;
    LeafOFTAdapter adapter;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address user = address(0xCAFE);

    function setUp() public {
        ep = new MockEndpointHbarx();
        inner = new MockERC20("HBARX", "HBARX");
        hts = new MockHtsPrecompile();
        vm.etch(address(0x167), address(hts).code);
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, feeTo, 2e11 * LeafHbarxPolicy.SHARE_SCALE);
        adapter.setShareScale(LeafHbarxPolicy.SHARE_SCALE);
        adapter.setPeer(30367, address(1));
        vm.stopPrank();
        _openSrc(adapter, owner, 2e11 * LeafHbarxPolicy.SHARE_SCALE);
        inner.mint(user, 2e11);
        vm.deal(user, 1 ether);
        vm.deal(address(adapter), 1 ether);
    }

    function _hts() internal view returns (MockHtsPrecompile) {
        return MockHtsPrecompile(address(0x167));
    }

    function testCatalogPins() public view {
        AssetCatalog.Listing memory a = AssetCatalog.get("hhbarx");
        assertEq(a.innerMainnet, LeafHbarxPolicy.HBARX);
        assertEq(a.sourceChainIdMain, 295);
        assertEq(a.sourceEidMain, 30316);
        assertEq(a.defaultCap, 1e11);
        assertFalse(a.productionEvm);
        assertEq(LeafLbtcPolicy.shareScaleOf("hhbarx"), LeafHbarxPolicy.SHARE_SCALE);
        assertEq(a.defaultCap * LeafLbtcPolicy.shareScaleOf("hhbarx"), 1e21);
        assertEq(A.eidForChainId(295), A.EID_HEDERA);
        assertEq(A.endpoint(295), A.ENDPOINT_HEDERA);
        assertEq(A.confirmationsForEid(30316), 5);
    }

    function testNotThisBatch() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hhbarx");
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }

    function testRequireHbarx() public {
        vm.expectRevert(LeafHbarxPolicy.NotHbarx.selector);
        this._require(address(1));
        LeafHbarxPolicy.requireHbarx(LeafHbarxPolicy.HBARX);
    }

    function _require(address inner_) external pure {
        LeafHbarxPolicy.requireHbarx(inner_);
    }

    function testAssociateThenWrapOnHedera() public {
        vm.chainId(295);
        vm.startPrank(user);
        inner.approve(address(adapter), 5e8);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e8, user);
        vm.stopPrank();
        assertTrue(_hts().associated(address(adapter), address(inner)));
        assertEq(adapter.totalLocked(), 5e8 * LeafHbarxPolicy.SHARE_SCALE);
        assertEq(inner.balanceOf(address(adapter)), 5e8);
    }

    function testAlreadyAssociatedOk() public {
        vm.chainId(295);
        vm.etch(address(0x167), address(hts).code);
        MockHtsPrecompile(address(0x167)).setCode(194);
        vm.startPrank(user);
        inner.approve(address(adapter), 1e8);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 1e8, user);
        vm.stopPrank();
        assertEq(inner.balanceOf(address(adapter)), 1e8);
    }

    function testAssociateFailReverts() public {
        vm.chainId(295);
        vm.etch(address(0x167), address(hts).code);
        MockHtsPrecompile(address(0x167)).setCode(21);
        vm.expectRevert(LeafHts.AssociateFailed.selector);
        adapter.associateInner();
    }

    function testAssociateNoopOffHedera() public {
        adapter.associateInner();
        vm.startPrank(user);
        inner.approve(address(adapter), 1e8);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 1e8, user);
        vm.stopPrank();
        assertEq(inner.balanceOf(address(adapter)), 1e8);
    }

    function testUnstakeSelectorsForbidden() public {
        vm.startPrank(owner);
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0x745400c9));
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0x2e17de78));
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0x23095721));
        vm.stopPrank();
        assertTrue(LeafForbiddenSelectors.hbarx(bytes4(0x745400c9)));
    }

    function testHederaDvnsSorted() public pure {
        address[] memory d = LeafSecurity.hederaOptionalDvns();
        assertTrue(uint160(d[0]) < uint160(d[1]));
        assertTrue(uint160(d[1]) < uint160(d[2]));
        assertEq(d[0], A.DVN_CANARY_HEDERA);
        assertEq(d[1], A.DVN_LZ_LABS_HEDERA);
        assertEq(d[2], A.DVN_HORIZEN_HEDERA);
    }
}
