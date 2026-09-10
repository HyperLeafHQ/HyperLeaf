// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {LeafSffPolicy} from "src/lz/LeafSffPolicy.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {MockConvertERC20} from "test/mocks/MockConvertERC20.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockEndpointSff is ILayerZeroEndpointV2 {
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

contract LeafSffTest is PegReady {
    MockEndpointSff ep;
    MockConvertERC20 inner;
    LeafOFTAdapter adapter;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address converter = address(0xC0DE);
    address user = address(0xCAFE);

    function setUp() public {
        ep = new MockEndpointSff();
        inner = new MockConvertERC20("sFF", "sFF");
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, feeTo, 1_000 ether);
        adapter.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
        adapter.setRetainRateYield(true);
        adapter.setMaxRateJumpBps(LeafSffPolicy.MAX_RATE_JUMP_BPS);
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
        AssetCatalog.Listing memory a = AssetCatalog.get("hsff");
        assertEq(a.innerMainnet, LeafSffPolicy.SFF);
        assertTrue(a.innerMainnet != LeafSffPolicy.FF);
        assertTrue(a.innerMainnet != LeafSffPolicy.PRIME);
        assertEq(a.sourceChainIdMain, 1);
        assertFalse(a.productionEvm);
        assertEq(AssetCatalog.get("hsFF").id, "hsff");
        assertEq(adapter.maxRateJumpBps(), LeafSffPolicy.MAX_RATE_JUMP_BPS);
    }

    function testRequireSffRejectsFfAndPrime() public {
        vm.expectRevert(LeafSffPolicy.NotSff.selector);
        this._require(LeafSffPolicy.FF);
        vm.expectRevert(LeafSffPolicy.NotSff.selector);
        this._require(LeafSffPolicy.PRIME);
        LeafSffPolicy.requireSff(LeafSffPolicy.SFF);
    }

    function _require(address inner_) external pure {
        LeafSffPolicy.requireSff(inner_);
    }

    function testNotThisBatch() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hsff");
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }

    function testCooldownForbidden() public view {
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x787a08a6)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x20fb80b5)));
        // QUID poke must stay allowed globally
        assertFalse(LeafForbiddenSelectors.forbidden(bytes4(0x9a99b4f0)));
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
}
