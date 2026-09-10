// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {LeafSghoPolicy} from "src/lz/LeafSghoPolicy.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {MockConvertERC20} from "test/mocks/MockConvertERC20.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockEndpointSgho is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30101;
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

contract LeafSghoTest is PegReady {
    MockEndpointSgho ep;
    MockConvertERC20 inner;
    LeafOFTAdapter adapter;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address converter = address(0xC0DE);
    address user = address(0xCAFE);

    function setUp() public {
        ep = new MockEndpointSgho();
        inner = new MockConvertERC20("sGHO", "sGHO");
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, feeTo, 1_000 ether);
        adapter.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
        adapter.setRetainRateYield(true);
        adapter.setConvertYieldToHype(true);
        adapter.setConverter(converter);
        adapter.setHarvester(owner);
        adapter.setPeer(30367, address(1));
        vm.stopPrank();
        _openSrc(adapter, owner, 1_000 ether);
        inner.mint(user, 200 ether);
        vm.deal(user, 1 ether);
    }

    function testCatalogPins() public view {
        AssetCatalog.Listing memory a = AssetCatalog.get("hsgho");
        assertEq(a.innerMainnet, LeafSghoPolicy.SGHO);
        assertTrue(a.innerMainnet != LeafSghoPolicy.GHO);
        assertEq(a.sourceChainIdMain, 1);
        assertEq(a.sourceEidMain, 30101);
        assertEq(a.defaultCap, 10_000 ether);
        assertFalse(a.productionEvm);
        assertEq(AssetCatalog.get("hsGHO").id, "hsgho");
    }

    function testRequireSghoRejectsGho() public {
        vm.expectRevert(LeafSghoPolicy.NotSgho.selector);
        this._require(LeafSghoPolicy.GHO);
        LeafSghoPolicy.requireSgho(LeafSghoPolicy.SGHO);
    }

    function _require(address inner_) external pure {
        LeafSghoPolicy.requireSgho(inner_);
    }

    function testNotThisBatch() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hsgho");
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }

    function testVaultMutatorsForbidden() public view {
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x6e553f65))); // deposit(uint256,address)
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xb460af94))); // withdraw
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xba087652))); // redeem
    }

    function testRateSkimOnePercent() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 100 ether);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 100 ether, user);
        vm.stopPrank();
        uint256 rate = 101 * 1e16;
        inner.setRate(rate);
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        uint256 surplus = (uint256(100 ether) * (rate - 1e18)) / rate;
        assertEq(inner.balanceOf(converter), (surplus * 100) / 10_000);
        assertEq(adapter.totalLocked(), 100 ether);
    }

    function testNoRewardsSelector() public {
        vm.prank(owner);
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0x6e553f65));
    }
}
