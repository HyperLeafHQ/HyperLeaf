// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {LeafListaPolicy} from "src/lz/LeafListaPolicy.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockListaManager {
    uint256 public rate = 1e18;

    function convertSnBnbToBnb(uint256 amt) external view returns (uint256) {
        return (amt * rate) / 1e18;
    }

    function setRate(uint256 r) external {
        rate = r;
    }
}

contract MockEndpointLista is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30102;
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

contract LeafListaTest is Test {
    MockEndpointLista ep;
    MockERC20 inner;
    MockListaManager manager;
    LeafOFTAdapter adapter;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);

    function setUp() public {
        ep = new MockEndpointLista();
        inner = new MockERC20("slisBNB", "slisBNB");
        manager = new MockListaManager();
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, feeTo, 1_000e18);
        adapter.setRewardsTarget(address(manager));
        adapter.setRateKind(LeafYieldFee.RateKind.ConvertSnBnbToBnb);
        adapter.setRetainRateYield(true);
        vm.stopPrank();
    }

    function testCatalogNotThisBatch() public {
        AssetCatalog.Listing memory a = AssetCatalog.get("hslisbnb");
        assertEq(a.innerMainnet, LeafListaPolicy.SLISBNB);
        assertEq(a.sourceChainIdMain, 56);
        assertEq(a.sourceEidMain, 30102);
        assertTrue(a.productionEvm);
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hslisbnb");
        vm.expectRevert(LeafListaPolicy.NotSlisBnb.selector);
        this._require(address(1));
        LeafListaPolicy.requireSlisBnb(LeafListaPolicy.SLISBNB);
    }

    function testRateReadsStakeManagerNotToken() public {
        assertEq(uint8(adapter.rateKind()), uint8(LeafYieldFee.RateKind.ConvertSnBnbToBnb));
        assertEq(adapter.lastRate(), 1e18);
        manager.setRate(1.05e18);
        vm.prank(owner);
        adapter.setRateKind(LeafYieldFee.RateKind.ConvertSnBnbToBnb);
        assertEq(adapter.lastRate(), 1.05e18);
    }

    function testListaExitSelectorsForbidden() public pure {
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x745400c9)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xb13acedd)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x9a53d5af)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xfd92bff2)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xd0e30db0)));
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }

    function _require(address inner_) external pure {
        LeafListaPolicy.requireSlisBnb(inner_);
    }
}
