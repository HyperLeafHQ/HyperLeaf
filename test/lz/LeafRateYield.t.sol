// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
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
        adapter.setConvertYieldToHype(true);
        adapter.setConverter(converter);
        adapter.setHarvester(owner);
        vm.stopPrank();
        _openPair(adapter, oft, owner, 1_000e18);
        inner.mint(user, 200e18);
        vm.deal(user, 1 ether);
    }

    uint64 nonce;

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

    function testRateSurplusGoesToConverterNotPrincipal() public {
        _mintLeaf(100e18);
        assertEq(adapter.totalLocked(), 100e18);
        inner.setRate(11e17);
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        // 100% of surplus leaves. The 1% protocol take is WHYPE at notify, not here.
        uint256 surplus = 100e18 - (100e18 * uint256(1e18)) / uint256(11e17);
        assertEq(inner.balanceOf(converter), surplus);
        assertEq(inner.balanceOf(address(adapter)), 100e18 - surplus);
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
}
