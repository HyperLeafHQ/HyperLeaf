// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {LeafBenqiPolicy} from "src/lz/LeafBenqiPolicy.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockSavax is MockERC20 {
    uint256 public pooled = 1e18;

    constructor() MockERC20("sAVAX", "sAVAX") {}

    function getPooledAvaxByShares(uint256 shares) external view returns (uint256) {
        return (shares * pooled) / 1e18;
    }

    function setPooled(uint256 r) external {
        pooled = r;
    }
}

contract MockEndpointAvax is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30106;
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

contract LeafSavaxTest is Test {
    MockEndpointAvax ep;
    MockSavax inner;
    LeafOFTAdapter adapter;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);

    function setUp() public {
        ep = new MockEndpointAvax();
        inner = new MockSavax();
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, feeTo, 100e18);
        adapter.setRateKind(LeafYieldFee.RateKind.GetPooledAvaxByShares);
        adapter.setRetainRateYield(true);
        vm.stopPrank();
    }

    function testCatalogAndPins() public {
        AssetCatalog.Listing memory a = AssetCatalog.get("hsavax");
        assertEq(a.innerMainnet, LeafBenqiPolicy.SAVAX);
        assertEq(a.sourceChainIdMain, 43114);
        assertEq(a.sourceEidMain, 30106);
        assertEq(MainnetBatches.batchOf("hsavax"), 3);
        LeafBenqiPolicy.requireSavax(LeafBenqiPolicy.SAVAX);
        vm.expectRevert(LeafBenqiPolicy.NotSavax.selector);
        this._require(address(1));
    }

    function testRateOnToken() public {
        assertEq(adapter.lastRate(), 1e18);
        inner.setPooled(1.2e18);
        vm.prank(owner);
        adapter.setRateKind(LeafYieldFee.RateKind.GetPooledAvaxByShares);
        assertEq(adapter.lastRate(), 1.2e18);
    }

    function testBenqiExitForbidden() public pure {
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xc9d2ff9d)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x2e1a7d4d)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x5bcb2fc6)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xa1903eab)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xdb006a75)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x819bfd9e)));
    }

    function _require(address inner_) external pure {
        LeafBenqiPolicy.requireSavax(inner_);
    }
}
