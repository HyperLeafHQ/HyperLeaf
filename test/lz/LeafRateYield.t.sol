// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockCbETH is ERC20 {
    uint256 public exchangeRate = 1e18;

    constructor() ERC20("cbETH", "cbETH") {}

    function mint(address to, uint256 a) external {
        _mint(to, a);
    }

    function setRate(uint256 r) external {
        exchangeRate = r;
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

contract LeafRateYieldTest is PegReady {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    MockCbETH inner;
    LeafOFTAdapter adapter;
    LeafOFT oft;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address converter = address(0xC0DE);
    address user = address(0xCAFE);
    uint32 constant SRC = 30184;
    uint32 constant DST = 30367;

    function setUp() public {
        epSrc = new MockEndpoint();
        epDst = new MockEndpoint();
        inner = new MockCbETH();
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(epSrc), owner, guardian, feeTo, 1_000e18);
        oft = new LeafOFT("hcbETH", "hcbETH", address(epDst), owner, guardian);
        adapter.setPeer(DST, address(oft));
        oft.setPeer(SRC, address(adapter));
        adapter.setRateKind(LeafYieldFee.RateKind.ExchangeRate);
        adapter.setRetainRateYield(true);
        adapter.setConvertYieldToHype(true);
        adapter.setConverter(converter);
        adapter.setHarvester(owner);
        vm.stopPrank();
        _openPair(adapter, oft, owner, 1_000e18);
        inner.mint(user, 200e18);
        vm.deal(user, 1 ether);
    }

    uint64 nonce;

    function _surplus(uint256 accounted, uint256 last, uint256 rate) internal pure returns (uint256) {
        if (rate <= last || accounted == 0) return 0;
        return (accounted * (rate - last)) / rate;
    }

    function _mintLeaf(uint256 assets) internal returns (uint256 shares) {
        uint256 before = adapter.totalLocked();
        vm.startPrank(user);
        inner.approve(address(adapter), assets);
        adapter.sendTo{value: 0.01 ether}(DST, user, assets);
        vm.stopPrank();
        shares = adapter.totalLocked() - before;
        bytes memory payload = _msg(oft, user, shares);
        nonce += 1;
        ILayerZeroEndpointV2.Origin memory oIn = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(adapter)))), nonce: nonce
        });
        vm.prank(address(epDst));
        oft.lzReceive(oIn, bytes32(uint256(nonce)), payload, address(0), "");
    }

    function _redeem(uint256 shares) internal {
        vm.prank(user);
        oft.sendTo{value: 0.01 ether}(SRC, user, shares);
        bytes memory payload = _msg(adapter, user, shares);
        nonce += 1;
        ILayerZeroEndpointV2.Origin memory oOut = ILayerZeroEndpointV2.Origin({
            srcEid: DST, sender: bytes32(uint256(uint160(address(oft)))), nonce: nonce
        });
        vm.prank(address(epSrc));
        adapter.lzReceive(oOut, bytes32(uint256(nonce)), payload, address(0), "");
    }

    function _fee(uint256 surplus) internal pure returns (uint256) {
        return (surplus * 100) / 10_000;
    }

    function testRateSurplusGoesToConverterNotPrincipal() public {
        _mintLeaf(100e18);
        assertEq(adapter.totalLocked(), 100e18);
        inner.setRate(11e17);
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        uint256 surplus = _surplus(100e18, 1e18, 11e17);
        uint256 fee = _fee(surplus);
        assertEq(inner.balanceOf(converter), fee);
        assertEq(inner.balanceOf(address(adapter)), 100e18 - fee);
        assertEq(adapter.totalLocked(), 100e18);
        vm.prank(owner);
        vm.expectRevert(LeafYieldFee.NoYield.selector);
        adapter.pullYield(inner, converter);
    }

    function testRedeemAfterHarvestIsProRata() public {
        _mintLeaf(100e18);
        inner.setRate(11e17);
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        uint256 remaining = inner.balanceOf(address(adapter));
        _redeem(100e18);
        assertEq(inner.balanceOf(user), 200e18 - 100e18 + remaining);
        assertEq(oft.totalSupply(), 0);
        assertEq(inner.balanceOf(address(adapter)), 0);
        // 99% of the rate surplus stayed in remaining cbETH (ETH value rose).
        assertGt(remaining, 99e18);
    }

    function testLaterDepositMintsAtNav() public {
        _mintLeaf(100e18);
        inner.setRate(11e17);
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        uint256 prev = inner.balanceOf(address(adapter));
        uint256 shares2 = _mintLeaf(10e18);
        assertEq(shares2, (10e18 * 100e18) / prev);
    }

    function testSlashLowersWatermarkNoPull() public {
        _mintLeaf(100e18);
        inner.setRate(95e16);
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        assertEq(adapter.lastRate(), 95e16);
        assertEq(inner.balanceOf(converter), 0);
    }

    function testNoRateFeedCannotPullInner() public {
        vm.prank(owner);
        adapter.setRateKind(LeafYieldFee.RateKind.None);
        vm.prank(owner);
        vm.expectRevert(LeafOFTAdapter.CannotPullInner.selector);
        adapter.pullYield(inner, converter);
    }

    function testWrapDoesNotPullToConverter() public {
        _mintLeaf(100e18);
        inner.setRate(11e17);
        uint256 shares2 = _mintLeaf(10e18);
        assertEq(inner.balanceOf(converter), 0);
        assertEq(adapter.accruedRateYield(), 0);
        // Retain: cbETH quantity NAV is still ~1:1 until the 1% skim.
        assertEq(shares2, 10e18);
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        uint256 surplus = _surplus(110e18, 1e18, 11e17);
        assertEq(inner.balanceOf(converter), _fee(surplus));
    }

    function testDonationIsNotYield() public {
        _mintLeaf(100e18);
        inner.mint(address(adapter), 100e18);
        vm.prank(owner);
        vm.expectRevert(LeafYieldFee.NoYield.selector);
        adapter.pullYield(inner, converter);
        assertEq(inner.balanceOf(converter), 0);
        assertEq(adapter.lastAccounted(), 100e18);

        inner.setRate(11e17);
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        uint256 surplus = _surplus(100e18, 1e18, 11e17);
        uint256 fee = _fee(surplus);
        assertEq(inner.balanceOf(converter), fee);
        // Donation remains as extra backing, not converted.
        assertEq(inner.balanceOf(address(adapter)), 200e18 - fee);
        assertEq(adapter.lastAccounted(), 100e18 - fee);
    }

    function testRoundingFloorsSurplus() public {
        _mintLeaf(100e18);
        inner.setRate(11e17);
        uint256 accounted = adapter.lastAccounted();
        uint256 add = _surplus(accounted, 1e18, 11e17);
        assertGe(add, 0);
        assertLe(add * uint256(11e17), accounted * (uint256(11e17) - uint256(1e18)));
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        uint256 fee = _fee(add);
        assertEq(inner.balanceOf(converter), fee);
        assertEq(adapter.lastAccounted() + fee, 100e18);
    }

    function testYieldConfigFrozenAfterDeposit() public {
        _mintLeaf(1e18);
        vm.startPrank(owner);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        adapter.setRetainRateYield(false);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        adapter.setRateKind(LeafYieldFee.RateKind.None);
        vm.stopPrank();
    }

    function testSellAllStillWorksWhenRetainOff() public {
        vm.prank(owner);
        adapter.setRetainRateYield(false);
        _mintLeaf(100e18);
        inner.setRate(11e17);
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        uint256 surplus = _surplus(100e18, 1e18, 11e17);
        assertEq(inner.balanceOf(converter), surplus);
        assertEq(inner.balanceOf(address(adapter)), 100e18 - surplus);
    }

    function testRateFuzzHighWaterMark(uint256 r1, uint256 r2, uint256 r3, uint256 r4) public {
        r1 = bound(r1, 5e17, 10e18);
        r2 = bound(r2, 5e17, 10e18);
        r3 = bound(r3, 5e17, 10e18);
        r4 = bound(r4, 5e17, 10e18);
        _mintLeaf(100e18);
        uint256 accounted = 100e18;
        uint256 last = 1e18;
        uint256 harvested;
        uint256[4] memory rates = [r1, r2, r3, r4];
        for (uint256 i; i < 4; i++) {
            inner.setRate(rates[i]);
            if (rates[i] < last) {
                vm.prank(owner);
                adapter.pullYield(inner, converter);
                last = rates[i];
                continue;
            }
            uint256 add = _surplus(accounted, last, rates[i]);
            uint256 fee = _fee(add);
            vm.prank(owner);
            if (fee == 0) {
                if (rates[i] == last) {
                    vm.expectRevert(LeafYieldFee.NoYield.selector);
                }
                adapter.pullYield(inner, converter);
                last = rates[i];
            } else {
                adapter.pullYield(inner, converter);
                harvested += fee;
                accounted -= fee;
                last = rates[i];
            }
        }
        assertEq(adapter.lastAccounted(), accounted);
        assertEq(inner.balanceOf(converter), harvested);
        assertEq(inner.balanceOf(address(adapter)), 100e18 - harvested);
        assertLe(harvested, 100e18);
        assertLe(accounted, 100e18);
    }
}

