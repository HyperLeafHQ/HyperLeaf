// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockToken is ERC20 {
    constructor() ERC20("inner", "IN") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
    function burn(address from, uint256 a) external {
        _burn(from, a);
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

contract LeafPegTest is PegReady {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    MockToken token;
    LeafOFTAdapter adapter;
    LeafOFT oft;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address user = address(0xCAFE);
    uint32 constant SRC = 30184;
    uint32 constant DST = 30367;

    function setUp() public {
        epSrc = new MockEndpoint();
        epDst = new MockEndpoint();
        token = new MockToken();
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(token), address(epSrc), owner, guardian, feeTo, 1_000e18);
        oft = new LeafOFT("hIN", "hIN", address(epDst), owner, guardian);
        adapter.setPeer(DST, address(oft));
        oft.setPeer(SRC, address(adapter));
        vm.stopPrank();
        token.mint(user, 500e18);
        vm.deal(user, 10 ether);
    }

    function testSendRevertsUntilBridgeOpen() public {
        vm.startPrank(user);
        token.approve(address(adapter), 1e18);
        vm.expectRevert(LeafOApp.BridgeClosedErr.selector);
        adapter.sendTo{value: 0.01 ether}(DST, user, 1e18);
        vm.stopPrank();
    }

    function testOpenRequiresTagAndLimits() public {
        vm.prank(owner);
        vm.expectRevert(LeafOApp.LimitsUnset.selector);
        adapter.openBridge();
        vm.startPrank(owner);
        adapter.setInnerSupplyCeiling(type(uint256).max);
        vm.expectRevert(LeafOApp.NoListingTag.selector);
        adapter.openBridge();
        adapter.setListingTag(TAG);
        vm.expectRevert(LeafOApp.LimitsUnset.selector);
        adapter.openBridge();
        adapter.setLimits(10e18, 10e18);
        adapter.openBridge();
        vm.stopPrank();
        assertTrue(adapter.bridgeOpen());
    }

    function testDegradedStopsMintAllowsRedeemPath() public {
        _openPair(adapter, oft, owner, 1_000e18);
        vm.startPrank(user);
        token.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        vm.prank(guardian);
        adapter.setHealth(LeafOApp.Health.Degraded);
        vm.startPrank(user);
        token.approve(address(adapter), 1e18);
        vm.expectRevert(LeafOApp.NotHealthy.selector);
        adapter.sendTo{value: 0.01 ether}(DST, user, 1e18);
        vm.stopPrank();
        bytes memory payload = _msg(adapter, user, 4e18);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: DST, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1
        });
        vm.prank(address(epSrc));
        adapter.lzReceive(origin, bytes32(uint256(2)), payload, address(0), "");
        assertEq(token.balanceOf(user), 494e18);
    }

    function testInnerSupplyCeilingRejectsMint() public {
        vm.startPrank(owner);
        adapter.setListingTag(TAG);
        adapter.setLimits(100e18, 100e18);
        adapter.setInnerSupplyCeiling(token.totalSupply());
        oft.setListingTag(TAG);
        oft.setLimits(100e18, 100e18);
        oft.setSupplyCap(1_000e18);
        adapter.openBridge();
        oft.openBridge();
        vm.stopPrank();
        token.mint(user, 1);
        vm.startPrank(user);
        token.approve(address(adapter), 1e18);
        vm.expectRevert(LeafOApp.InnerSupplyBreach.selector);
        adapter.sendTo{value: 0.01 ether}(DST, user, 1e18);
        vm.stopPrank();
        adapter.reportInnerSupply();
        assertEq(uint8(adapter.health()), uint8(LeafOApp.Health.Degraded));
        vm.prank(owner);
        vm.expectRevert(LeafOApp.InnerSupplyBreach.selector);
        adapter.restoreHealth(LeafOApp.Health.Normal);
    }

    function testReportInnerSupplyIgnoresForeignToken() public {
        _openPair(adapter, oft, owner, 1_000e18);
        adapter.reportInnerSupply();
        assertEq(uint8(adapter.health()), uint8(LeafOApp.Health.Normal));
        assertEq(adapter.canonicalInner(), address(token));
    }

    function testInsolventBlocksRedeem() public {
        _openPair(adapter, oft, owner, 1_000e18);
        vm.startPrank(user);
        token.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        vm.prank(guardian);
        adapter.setHealth(LeafOApp.Health.Insolvent);
        bytes memory payload = _msg(adapter, user, 1e18);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: DST, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1
        });
        vm.prank(address(epSrc));
        vm.expectRevert(LeafOApp.NotSolvent.selector);
        adapter.lzReceive(origin, bytes32(uint256(2)), payload, address(0), "");
    }

    function testWrongListingTagRejected() public {
        _openPair(adapter, oft, owner, 1_000e18);
        bytes memory bad = abi.encode(keccak256("other"), bytes32(uint256(uint160(user))), uint256(1e18));
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(adapter)))), nonce: 1
        });
        vm.prank(address(epDst));
        vm.expectRevert(LeafOApp.WrongListing.selector);
        oft.lzReceive(origin, bytes32(uint256(1)), bad, address(0), "");
    }

    function testTxCap() public {
        vm.startPrank(owner);
        adapter.setListingTag(TAG);
        adapter.setLimits(5e18, 100e18);
        adapter.setInnerSupplyCeiling(type(uint256).max);
        oft.setListingTag(TAG);
        oft.setLimits(5e18, 100e18);
        oft.setSupplyCap(1_000e18);
        adapter.openBridge();
        oft.openBridge();
        vm.stopPrank();
        vm.startPrank(user);
        token.approve(address(adapter), 10e18);
        vm.expectRevert(LeafOApp.TxCapExceeded.selector);
        adapter.sendTo{value: 0.01 ether}(DST, user, 6e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 5e18);
        vm.stopPrank();
    }

    function testDayCap() public {
        vm.startPrank(owner);
        adapter.setListingTag(TAG);
        adapter.setLimits(10e18, 10e18);
        adapter.setInnerSupplyCeiling(type(uint256).max);
        oft.setListingTag(TAG);
        oft.setLimits(10e18, 10e18);
        oft.setSupplyCap(1_000e18);
        adapter.openBridge();
        oft.openBridge();
        vm.stopPrank();
        vm.startPrank(user);
        token.approve(address(adapter), 20e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 8e18);
        vm.expectRevert(LeafOApp.DayCapExceeded.selector);
        adapter.sendTo{value: 0.01 ether}(DST, user, 3e18);
        vm.warp(block.timestamp + 1 days);
        adapter.sendTo{value: 0.01 ether}(DST, user, 3e18);
        vm.stopPrank();
    }

    function testRedeemRevertsIfUnderbacked() public {
        _openPair(adapter, oft, owner, 1_000e18);
        vm.startPrank(user);
        token.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        token.burn(address(adapter), 10e18);
        bytes memory payload = _msg(adapter, user, 10e18);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: DST, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1
        });
        vm.prank(address(epSrc));
        vm.expectRevert(LeafOApp.Underbacked.selector);
        adapter.lzReceive(origin, bytes32(uint256(2)), payload, address(0), "");
    }

    function testGuardianCloseStopsMint() public {
        _openPair(adapter, oft, owner, 1_000e18);
        vm.prank(guardian);
        adapter.closeBridge();
        assertFalse(adapter.bridgeOpen());
        vm.startPrank(user);
        token.approve(address(adapter), 1e18);
        vm.expectRevert();
        adapter.sendTo{value: 0.01 ether}(DST, user, 1e18);
        vm.stopPrank();
        vm.prank(owner);
        adapter.unpause();
        vm.startPrank(user);
        vm.expectRevert(LeafOApp.BridgeClosedErr.selector);
        adapter.sendTo{value: 0.01 ether}(DST, user, 1e18);
        vm.stopPrank();
    }

    function testSupplyCapOnMint() public {
        vm.startPrank(owner);
        oft.setListingTag(TAG);
        oft.setLimits(100e18, 100e18);
        oft.setSupplyCap(5e18);
        oft.openBridge();
        vm.stopPrank();
        bytes memory payload = _msg(oft, user, 6e18);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(adapter)))), nonce: 1
        });
        vm.prank(address(epDst));
        vm.expectRevert(LeafOFT.SupplyCapExceeded.selector);
        oft.lzReceive(origin, bytes32(uint256(1)), payload, address(0), "");
    }

    function testUnpauseDoesNotReopenBridge() public {
        _openPair(adapter, oft, owner, 1_000e18);
        vm.prank(guardian);
        adapter.closeBridge();
        vm.prank(owner);
        adapter.unpause();
        assertFalse(adapter.bridgeOpen());
        assertFalse(adapter.paused());
        vm.startPrank(user);
        token.approve(address(adapter), 1e18);
        vm.expectRevert(LeafOApp.BridgeClosedErr.selector);
        adapter.sendTo{value: 0.01 ether}(DST, user, 1e18);
        vm.stopPrank();
        vm.prank(owner);
        adapter.openBridge();
        vm.startPrank(user);
        adapter.sendTo{value: 0.01 ether}(DST, user, 1e18);
        vm.stopPrank();
        assertEq(adapter.totalLocked(), 1e18);
    }

    function testSourceDayCapBoundsRealOutflow() public {
        vm.startPrank(owner);
        adapter.setListingTag(TAG);
        adapter.setLimits(10e18, 10e18);
        adapter.setInnerSupplyCeiling(type(uint256).max);
        oft.setListingTag(TAG);
        oft.setLimits(100e18, 100e18);
        oft.setSupplyCap(1_000e18);
        adapter.openBridge();
        oft.openBridge();
        vm.stopPrank();
        vm.startPrank(user);
        token.approve(address(adapter), 20e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        bytes memory first = _msg(adapter, user, 10e18);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: DST, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1
        });
        vm.prank(address(epSrc));
        vm.expectRevert(LeafOApp.DayCapExceeded.selector);
        adapter.lzReceive(origin, bytes32(uint256(2)), first, address(0), "");
    }

    function testWrongPeerRejected() public {
        _openPair(adapter, oft, owner, 1_000e18);
        bytes memory payload = _msg(oft, user, 1e18);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(0xBEEF)))), nonce: 1
        });
        vm.prank(address(epDst));
        vm.expectRevert(LeafOApp.OnlyPeer.selector);
        oft.lzReceive(origin, bytes32(uint256(1)), payload, address(0), "");
    }

    function testPeerFrozenAfterOpen() public {
        _openPair(adapter, oft, owner, 1_000e18);
        vm.prank(owner);
        vm.expectRevert(LeafOApp.PeerFrozen.selector);
        adapter.setPeer(DST, address(0xBEEF));
        vm.prank(owner);
        adapter.setPeer(30102, address(0xBEEF));
        assertEq(adapter.peers(30102), bytes32(uint256(uint160(address(0xBEEF)))));
        assertEq(adapter.peers(DST), bytes32(uint256(uint160(address(oft)))));
    }

    function testCrossListingTagDoesNotMintOther() public {
        _openPair(adapter, oft, owner, 1_000e18);
        vm.startPrank(owner);
        LeafOFT other = new LeafOFT("hOTHER", "hOTHER", address(epDst), owner, guardian);
        other.setPeer(SRC, address(adapter));
        other.setListingTag(keccak256("other-listing"));
        other.setLimits(1_000e18, 1_000e18);
        other.setSupplyCap(1_000e18);
        other.openBridge();
        vm.stopPrank();
        bytes memory payload = _msg(oft, user, 1e18);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(adapter)))), nonce: 1
        });
        vm.prank(address(epDst));
        vm.expectRevert(LeafOApp.WrongListing.selector);
        other.lzReceive(origin, bytes32(uint256(1)), payload, address(0), "");
        assertEq(other.totalSupply(), 0);
    }

    function testAbortCreditOnlyAfterHalt() public {
        _openPair(adapter, oft, owner, 1_000e18);
        vm.startPrank(user);
        token.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        uint256 userBal = token.balanceOf(user);
        vm.prank(owner);
        vm.expectRevert(LeafOApp.NotSolvent.selector);
        adapter.abortCredit(user, 10e18);
        vm.prank(guardian);
        adapter.setHealth(LeafOApp.Health.Halted);
        vm.prank(owner);
        adapter.abortCredit(user, 10e18);
        assertEq(adapter.totalLocked(), 0);
        assertEq(token.balanceOf(user), userBal + 10e18);
    }

    function testTinyYieldFeeRoundsToZeroNotTrap() public {
        _openPair(adapter, oft, owner, 1_000e18);
        vm.startPrank(user);
        token.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        token.mint(address(adapter), 50);
        uint256 feeBefore = token.balanceOf(feeTo);
        adapter.harvest();
        assertEq(token.balanceOf(feeTo), feeBefore);
        assertEq(adapter.lastAccounted(), 10e18 + 50);
    }
}
