// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {LeafSpolPolicy as P} from "src/lz/LeafSpolPolicy.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockSpol is ERC20 {
    constructor() ERC20("Staked POL", "sPOL") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockSpolController {
    uint256 public polPerSpol = 1e18;
    function convertSPOLtoPOL(uint256 spol) external view returns (uint256) {
        return (spol * polPerSpol) / 1e18;
    }
    function convertPOLtoSPOL(uint256 pol) external view returns (uint256) {
        return (pol * 1e18) / polPerSpol;
    }
    function setRate(uint256 r) external {
        polPerSpol = r;
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 1;
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

contract LeafSpolTest is PegReady {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    MockSpol inner;
    MockSpolController ctrl;
    LeafOFTAdapter adapter;
    LeafOFT oft;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address converter = address(0xC0DE);
    address user = address(0xCAFE);
    uint32 constant SRC = 30101;
    uint32 constant DST = 30367;

    function setUp() public {
        epSrc = new MockEndpoint();
        epDst = new MockEndpoint();
        inner = new MockSpol();
        ctrl = new MockSpolController();
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(epSrc), owner, guardian, feeTo, 50e18);
        oft = new LeafOFT("hsPOL", "hsPOL", address(epDst), owner, guardian);
        adapter.setPeer(DST, address(oft));
        oft.setPeer(SRC, address(adapter));
        adapter.setRewardsTarget(address(ctrl));
        adapter.setMaxRateJumpBps(P.MAX_RATE_JUMP_BPS);
        adapter.setRateKind(LeafYieldFee.RateKind.ConvertSpolToPol);
        adapter.setRetainRateYield(true);
        adapter.setConvertYieldToHype(true);
        adapter.setConverter(converter);
        adapter.setHarvester(owner);
        vm.stopPrank();
        _openPair(adapter, oft, owner, 50e18);
        inner.mint(user, 200e18);
        vm.deal(user, 1 ether);
    }

    function _surplus(uint256 accounted, uint256 last, uint256 rate) internal pure returns (uint256) {
        if (rate <= last || accounted == 0) return 0;
        return (accounted * (rate - last)) / rate;
    }

    function testPins() public pure {
        assertEq(P.SPOL, 0x3B790d651e950497c7723D47B24E6f61534f7969);
        assertEq(P.CONTROLLER, 0xEaadA411F2600570796c341552b9869DA708a28B);
        assertEq(P.POL, 0x455e53CBB86018Ac2B8092FdCd39d8444aFFC3F6);
        assertEq(P.CONVERT_SPOL_TO_POL, bytes4(0xff8aaf7a));
        assertEq(P.CONVERT_POL_TO_SPOL, bytes4(0xc356a582));
        assertTrue(LeafForbiddenSelectors.forbidden(P.CONVERT_SPOL_TO_POL));
        assertTrue(LeafForbiddenSelectors.forbidden(P.CONVERT_POL_TO_SPOL));
        assertTrue(LeafForbiddenSelectors.forbidden(P.SELL_SPOL));
        assertTrue(LeafForbiddenSelectors.forbidden(P.BUY_SPOL));
        assertTrue(LeafForbiddenSelectors.forbidden(P.WITHDRAW_POL));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x32f42f13))); // sellSPOL(uint256,uint16)
        P.requireSpol(P.SPOL);
        P.requireController(P.CONTROLLER);
        P.requireEth(1);
    }

    function testRejectsChildAndPol() public {
        vm.expectRevert(P.WrongInner.selector);
        this._requireSpol(P.CHILD);
        vm.expectRevert(P.WrongInner.selector);
        this._requireSpol(P.POL);
        vm.expectRevert(P.WrongChain.selector);
        this._requireEth(137);
    }

    function _requireSpol(address t) external pure {
        P.requireSpol(t);
    }
    function _requireEth(uint256 c) external pure {
        P.requireEth(c);
    }

    function testRateKindNeedsControllerFirst() public {
        vm.startPrank(owner);
        LeafOFTAdapter box = new LeafOFTAdapter(address(inner), address(epSrc), owner, guardian, feeTo, 50e18);
        vm.expectRevert(LeafYieldFee.BadRateFeed.selector);
        box.setRateKind(LeafYieldFee.RateKind.ConvertSpolToPol);
        box.setRewardsTarget(address(ctrl));
        box.setRateKind(LeafYieldFee.RateKind.ConvertSpolToPol);
        vm.stopPrank();
        assertEq(uint8(box.rateKind()), uint8(LeafYieldFee.RateKind.ConvertSpolToPol));
    }

    function testSkimOnePercentRetainsNinetyNine() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 40e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 40e18);
        vm.stopPrank();
        ctrl.setRate(1012347237242067203); // live 2026-09-10
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        uint256 surplus = _surplus(40e18, 1e18, 1012347237242067203);
        assertEq(inner.balanceOf(converter), surplus / 100);
        assertEq(adapter.totalLocked(), 40e18);
        assertGt(inner.balanceOf(address(adapter)), 40e18 - surplus / 100 - 1);
    }

    function testCannotPokeConvert() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 40e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 40e18);
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        adapter.setRewardsSelector(P.CONVERT_SPOL_TO_POL);
        vm.prank(owner);
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        this._setSelFresh(P.CONVERT_SPOL_TO_POL);
    }

    function _setSelFresh(bytes4 s) external {
        LeafOFTAdapter box = new LeafOFTAdapter(address(inner), address(epSrc), owner, guardian, feeTo, 50e18);
        vm.prank(owner);
        box.setRewardsSelector(s);
    }

    function testNotThisBatch() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch();
        assertEq(AssetCatalog.get("hspol").innerMainnet, P.SPOL);
    }

    function _batch() external pure returns (uint8) {
        return MainnetBatches.batchOf("hspol");
    }
}
