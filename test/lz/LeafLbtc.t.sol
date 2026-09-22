// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {LeafLbtcPolicy} from "src/lz/LeafLbtcPolicy.sol";
import {LeafUmbrellaPolicy} from "src/lz/LeafUmbrellaPolicy.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockLbtcRouter} from "test/mocks/MockLbtcRouter.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockLbtc8Dec is ERC20 {
    constructor() ERC20("LBTC", "LBTC") {}

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockEndpointLbtc is ILayerZeroEndpointV2 {
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

contract LeafLbtcTest is PegReady {
    MockEndpointLbtc ep;
    MockERC20 inner;
    MockLbtcRouter router;
    LeafOFTAdapter adapter;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address converter = address(0xC0DE);
    address user = address(0xCAFE);

    function setUp() public {
        ep = new MockEndpointLbtc();
        inner = new MockERC20("LBTC", "LBTC");
        router = new MockLbtcRouter();
        router.setRate(address(inner), 1e18);
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, feeTo, 2e8);
        adapter.setConverter(converter);
        adapter.setRewardsTarget(address(router));
        adapter.setShareScale(LeafLbtcPolicy.SHARE_SCALE);
        adapter.setMaxRateJumpBps(LeafLbtcPolicy.MAX_RATE_JUMP_BPS);
        adapter.setRateKind(LeafYieldFee.RateKind.RouterGetRate);
        adapter.setRetainRateYield(true);
        adapter.setConvertYieldToHype(true);
        adapter.setPeer(30367, address(1));
        vm.stopPrank();
        _openSrc(adapter, owner, 2e8 * LeafLbtcPolicy.SHARE_SCALE);
        inner.mint(user, 2e8);
        vm.deal(user, 1 ether);
    }

    function testCatalogPins() public view {
        AssetCatalog.Listing memory a = AssetCatalog.get("hlbtc");
        assertEq(a.innerMainnet, LeafLbtcPolicy.LBTC);
        assertTrue(a.innerMainnet != LeafLbtcPolicy.BTCB);
        assertTrue(a.innerMainnet != LeafLbtcPolicy.LBTCV);
        assertTrue(a.innerMainnet != LeafLbtcPolicy.BTCE);
        assertTrue(a.innerMainnet != LeafLbtcPolicy.BASE_LBTC);
        assertEq(a.defaultCap, 0);
        assertEq(LeafLbtcPolicy.shareScaleOf("hlbtc"), LeafLbtcPolicy.SHARE_SCALE);
        assertEq(LeafLbtcPolicy.SHARE_SCALE, 1e10);
        assertEq(a.sourceChainIdMain, 1);
        assertEq(MainnetBatches.batchOf("hlbtc"), 3);
        assertEq(LeafLbtcPolicy.INNER_DECIMALS, 8);
        assertEq(
            LeafLbtcPolicy.shareScaleOf("hlbtc") * LeafUmbrellaPolicy.shareScaleOf("hlbtc"),
            LeafLbtcPolicy.SHARE_SCALE
        );
        assertEq(LeafUmbrellaPolicy.shareScaleOf("hlbtc"), 1);
        assertEq(LeafLbtcPolicy.shareScaleOf("hstkwausdc"), 1);
    }

    function testRequireLbtcRejectsCousins() public {
        vm.expectRevert(LeafLbtcPolicy.NotLbtc.selector);
        this._require(LeafLbtcPolicy.BTCB);
        vm.expectRevert(LeafLbtcPolicy.NotLbtc.selector);
        this._require(LeafLbtcPolicy.LBTCV);
        vm.expectRevert(LeafLbtcPolicy.NotLbtc.selector);
        this._require(LeafLbtcPolicy.BTCE);
        vm.expectRevert(LeafLbtcPolicy.NotLbtc.selector);
        this._require(LeafLbtcPolicy.BASE_LBTC);
        LeafLbtcPolicy.requireLbtc(LeafLbtcPolicy.LBTC);
    }

    function _require(address inner_) external pure {
        LeafLbtcPolicy.requireLbtc(inner_);
    }

    function testEightDecSharesScale() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 5e6);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
        assertEq(adapter.totalLocked(), 5e6 * LeafLbtcPolicy.SHARE_SCALE);
        assertEq(inner.balanceOf(address(adapter)), 5e6);
    }

    function testShareScaleFrozenAfterDeposit() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 5e6);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
        vm.startPrank(owner);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        adapter.setShareScale(1);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        adapter.setMaxRateJumpBps(1);
        vm.stopPrank();
    }

    function testLombardSelectorsForbidden() public {
        vm.startPrank(owner);
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0x42966c68));
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0xbcf64e05));
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0x6bc63893));
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0x8340f549));
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0xe5c1bf6e));
        vm.stopPrank();
    }

    function testRateJumpStopsMintNotRedeem() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 1e8);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
        router.setRate(address(inner), 1.1e18);
        adapter.pokeRate();
        assertTrue(adapter.rateJumped());
        vm.startPrank(user);
        inner.approve(address(adapter), 5e6);
        vm.expectRevert(LeafOApp.NotHealthy.selector);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
        vm.prank(guardian);
        adapter.acknowledgeRate();
        assertFalse(adapter.rateJumped());
        vm.startPrank(user);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
    }

    function testDownwardJumpStopsMintNoFee() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 5e6);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
        uint256 before = inner.balanceOf(address(adapter));
        router.setRate(address(inner), 0.96e18);
        adapter.pokeRate();
        assertTrue(adapter.rateJumped());
        assertEq(adapter.lastRate(), 1e18);
        assertEq(inner.balanceOf(address(adapter)), before);
        vm.expectRevert(LeafYieldFee.NoYield.selector);
        adapter.pullYield(inner, converter);
        vm.startPrank(user);
        inner.approve(address(adapter), 5e6);
        vm.expectRevert(LeafOApp.NotHealthy.selector);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
    }

    function testSmallDownDoesNotTrip() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 5e6);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
        router.setRate(address(inner), 0.98e18);
        adapter.pokeRate();
        assertFalse(adapter.rateJumped());
        assertEq(adapter.lastRate(), 1e18);
    }

    function testJumpIsNotHarvested() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 5e6);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
        router.setRate(address(inner), 1.1e18);
        adapter.pokeRate();
        vm.expectRevert(LeafYieldFee.NoYield.selector);
        adapter.pullYield(inner, converter);
        assertEq(inner.balanceOf(address(adapter)), 5e6);
    }

    function testSmallRateBumpSkimsOnePercent() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 5e6);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
        router.setRate(address(inner), 1.01e18);
        uint256 before = inner.balanceOf(converter);
        adapter.pullYield(inner, converter);
        // add = 5e6 * 0.01e18 / 1.01e18 = 49504; fee = 495
        assertEq(inner.balanceOf(converter) - before, 495);
        assertEq(inner.balanceOf(address(adapter)), 5e6 - 495);
    }

    function testEightDecRoundTrip() public {
        MockLbtc8Dec stk = new MockLbtc8Dec();
        MockEndpointLbtc epDst = new MockEndpointLbtc();
        MockLbtcRouter r = new MockLbtcRouter();
        r.setRate(address(stk), 1e18);
        assertEq(IERC20Metadata(address(stk)).decimals(), 8);
        vm.startPrank(owner);
        LeafOFTAdapter box = new LeafOFTAdapter(address(stk), address(ep), owner, guardian, feeTo, 0);
        LeafOFT dest = new LeafOFT("hLBTC", "hLBTC", address(epDst), owner, guardian);
        box.setPeer(30367, address(dest));
        dest.setPeer(30101, address(box));
        box.setConverter(converter);
        box.setRewardsTarget(address(r));
        box.setShareScale(LeafLbtcPolicy.SHARE_SCALE);
        box.setMaxRateJumpBps(LeafLbtcPolicy.MAX_RATE_JUMP_BPS);
        box.setRateKind(LeafYieldFee.RateKind.RouterGetRate);
        box.setRetainRateYield(true);
        box.setConvertYieldToHype(true);
        vm.stopPrank();
        _openPair(box, dest, owner, 1_000e18);
        stk.mint(user, 2e8);
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        stk.approve(address(box), 1e8);
        box.sendTo{value: 0.01 ether}(30367, user, 1e8);
        vm.stopPrank();
        assertEq(box.totalLocked(), 1e18);
        assertEq(stk.balanceOf(address(box)), 1e8);

        bytes memory payload = _msg(dest, user, 1e18);
        ILayerZeroEndpointV2.Origin memory oIn = ILayerZeroEndpointV2.Origin({
            srcEid: 30101, sender: bytes32(uint256(uint160(address(box)))), nonce: 1
        });
        vm.prank(address(epDst));
        dest.lzReceive(oIn, bytes32(uint256(1)), payload, address(0), "");
        assertEq(dest.balanceOf(user), 1e18);
        assertEq(dest.decimals(), 18);

        vm.startPrank(owner);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        box.setShareScale(1);
        vm.stopPrank();

        vm.startPrank(user);
        dest.sendTo{value: 0.01 ether}(30101, user, 1e18);
        vm.stopPrank();
        bytes memory back = _msg(box, user, 1e18);
        ILayerZeroEndpointV2.Origin memory oOut = ILayerZeroEndpointV2.Origin({
            srcEid: 30367, sender: bytes32(uint256(uint160(address(dest)))), nonce: 1
        });
        vm.prank(address(ep));
        box.lzReceive(oOut, bytes32(uint256(1)), back, address(0), "");
        assertEq(stk.balanceOf(user), 2e8);
        assertEq(box.totalLocked(), 0);
        assertEq(dest.balanceOf(user), 0);
    }
}
