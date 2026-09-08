// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafHypeRewarder} from "src/lz/LeafHypeRewarder.sol";
import {LeafClaimEscrow} from "src/lz/LeafClaimEscrow.sol";
import {LeafClaimFill} from "src/lz/LeafClaimFill.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockToken is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    uint32 public eid;
    constructor(uint32 eid_) {
        eid = eid_;
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

contract LeafClaimEscrowTest is PegReady {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    MockToken bluai;
    MockToken whype;
    LeafOFTAdapter adapter;
    LeafClosedOFT oft;
    LeafHypeRewarder rewarder;
    LeafClaimEscrow escrow;
    LeafClaimFill filler;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address alice = address(0xA1);
    address bob = address(0xB0);
    bytes32 constant ID = keccak256("bluai4y");
    uint32 constant DST = 30367;
    uint32 constant SRC = 30102;

    function setUp() public {
        epSrc = new MockEndpoint(SRC);
        epDst = new MockEndpoint(DST);
        bluai = new MockToken("BLUAI", "BLUAI");
        whype = new MockToken("WHYPE", "WHYPE");
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(bluai), address(epSrc), owner, guardian, feeTo, 10_000e18);
        oft = new LeafClosedOFT("BLUAI4Y", "BLUAI4Y", 4 * 365 days, address(epDst), owner, guardian);
        rewarder = new LeafHypeRewarder(address(whype), owner, feeTo);
        oft.setHypeRewarder(address(rewarder), ID);
        rewarder.register(ID, address(oft));
        adapter.setPeer(DST, address(oft));
        oft.setPeer(SRC, address(adapter));
        escrow = new LeafClaimEscrow(address(epDst), owner, guardian, feeTo);
        filler = new LeafClaimFill(address(epSrc), owner, guardian);
        escrow.setPeer(SRC, address(filler));
        filler.setPeer(DST, address(escrow));
        escrow.setMarket(address(oft), address(bluai), ID, true);
        escrow.setRewarder(address(rewarder));
        filler.setInner(address(bluai), true);
        filler.setReturnNative(0.01 ether);
        vm.stopPrank();
        _openPair(adapter, oft, owner, 10_000e18);
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        vm.deal(guardian, 1 ether);
        vm.deal(owner, 1 ether);
        vm.deal(address(escrow), 1 ether);
        vm.deal(address(filler), 1 ether);
        vm.deal(address(this), 1 ether);
        vm.deal(address(epDst), 1 ether);
        vm.deal(address(epSrc), 1 ether);
    }

    function _mintAlice(uint256 n) internal {
        bluai.mint(alice, n);
        vm.startPrank(alice);
        bluai.approve(address(adapter), n);
        adapter.sendTo{value: 0.01 ether}(DST, alice, n);
        vm.stopPrank();
        bytes memory payload = _msg(oft, alice, n);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(adapter)))), nonce: 1
        });
        vm.prank(address(epDst));
        oft.lzReceive(origin, bytes32(uint256(1)), payload, address(0), "");
    }

    function _list(uint256 leafAmt, uint256 ask) internal returns (uint256 id) {
        vm.startPrank(alice);
        oft.approve(address(escrow), leafAmt);
        id = escrow.list(address(oft), leafAmt, address(bluai), ask, alice, uint64(block.timestamp + 7 days));
        vm.stopPrank();
    }

    function testFillLocalBuyerRewardNoMint() public {
        _mintAlice(100e18);
        uint256 supply = oft.totalSupply();
        uint256 id = _list(100e18, 70e18);
        bluai.mint(bob, 70e18);
        vm.startPrank(bob);
        bluai.approve(address(escrow), 70e18);
        escrow.fillLocal(id);
        vm.stopPrank();
        assertEq(oft.balanceOf(bob), 100e18);
        assertEq(oft.balanceOf(alice), 0);
        assertEq(bluai.balanceOf(alice), 69.3e18);
        assertEq(bluai.balanceOf(bob), 0.7e18);
        assertEq(oft.totalSupply(), supply);
        (,,,,,,, LeafClaimEscrow.Status st) = escrow.orders(id);
        assertEq(uint8(st), uint8(LeafClaimEscrow.Status.Filled));
    }

    function testFillDoesNotTouchLockbox() public {
        _mintAlice(100e18);
        assertEq(adapter.totalLocked(), 100e18);
        uint256 supply = oft.totalSupply();
        uint256 id = _list(100e18, 70e18);
        bluai.mint(bob, 70e18);
        vm.startPrank(bob);
        bluai.approve(address(escrow), 70e18);
        escrow.fillLocal(id);
        vm.stopPrank();
        assertEq(adapter.totalLocked(), 100e18);
        assertEq(oft.totalSupply(), supply);
        assertEq(bluai.balanceOf(address(adapter)), 100e18);
    }

    function testCannotFillTwice() public {
        _mintAlice(100e18);
        uint256 id = _list(100e18, 70e18);
        bluai.mint(bob, 140e18);
        vm.startPrank(bob);
        bluai.approve(address(escrow), 140e18);
        escrow.fillLocal(id);
        vm.expectRevert(LeafClaimEscrow.NotOpen.selector);
        escrow.fillLocal(id);
        vm.stopPrank();
    }

    function testCancelReturnsLeafNoFee() public {
        _mintAlice(100e18);
        uint256 id = _list(100e18, 70e18);
        vm.prank(alice);
        escrow.cancel(id, 0);
        assertEq(oft.balanceOf(alice), 100e18);
        (,,,,,,, LeafClaimEscrow.Status st) = escrow.orders(id);
        assertEq(uint8(st), uint8(LeafClaimEscrow.Status.Cancelled));
    }

    function testSellerKeepsHistoricalHypeOccupancyToProtocol() public {
        _mintAlice(100e18);
        whype.mint(address(this), 100e18);
        whype.approve(address(rewarder), 100e18);
        rewarder.notify(ID, 100e18);
        uint256 sellerDue = rewarder.pending(ID, alice);
        assertEq(sellerDue, 99e18);
        uint256 id = _list(100e18, 70e18);
        assertEq(rewarder.pending(ID, alice), sellerDue);
        assertEq(rewarder.pending(ID, address(escrow)), 0);

        whype.mint(address(this), 100e18);
        whype.approve(address(rewarder), 100e18);
        rewarder.notify(ID, 100e18);
        assertEq(rewarder.pending(ID, alice), sellerDue);
        assertEq(rewarder.pending(ID, address(escrow)), 99e18);

        escrow.claimOccupancy(ID);
        assertEq(whype.balanceOf(feeTo), 2e18 + 99e18); // 1+1 from notify fees, + 99 occupancy
        assertEq(rewarder.pending(ID, address(escrow)), 0);

        vm.prank(alice);
        escrow.cancel(id, 0);
        assertEq(oft.balanceOf(alice), 100e18);
        vm.prank(alice);
        rewarder.claim(ID, alice);
        assertEq(whype.balanceOf(alice), sellerDue);
    }

    function testExpireReturnsLeaf() public {
        _mintAlice(100e18);
        uint256 id = _list(100e18, 70e18);
        vm.warp(block.timestamp + 8 days);
        escrow.expire(id, 0);
        assertEq(oft.balanceOf(alice), 100e18);
        (,,,,,,, LeafClaimEscrow.Status st) = escrow.orders(id);
        assertEq(uint8(st), uint8(LeafClaimEscrow.Status.Expired));
    }

    function testProtocolCannotBeCounterparty() public {
        _mintAlice(100e18);
        uint256 id = _list(100e18, 70e18);
        bluai.mint(alice, 70e18);
        vm.startPrank(alice);
        bluai.approve(address(escrow), 70e18);
        vm.expectRevert(LeafClaimEscrow.SameParty.selector);
        escrow.fillLocal(id);
        vm.stopPrank();
    }

    function testLzFillThenAck() public {
        _mintAlice(100e18);
        uint256 supply = oft.totalSupply();
        uint256 id = _list(100e18, 70e18);
        bluai.mint(bob, 70e18);
        vm.startPrank(bob);
        bluai.approve(address(filler), 70e18);
        filler.fill{value: 0.01 ether}(id, DST, address(bluai), 70e18, alice);
        vm.stopPrank();
        assertEq(bluai.balanceOf(address(filler)), 70e18);
        assertEq(oft.balanceOf(address(escrow)), 100e18);

        bytes memory fillMsg = abi.encode(uint8(1), id, bob, uint256(70e18), alice);
        ILayerZeroEndpointV2.Origin memory oFill = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(filler)))), nonce: 1
        });
        vm.prank(address(epDst));
        escrow.lzReceive{value: 0.01 ether}(oFill, bytes32(uint256(1)), fillMsg, address(0), "");
        assertEq(oft.balanceOf(bob), 100e18);
        assertEq(oft.totalSupply(), supply);

        bytes memory ack = abi.encode(uint8(2), id);
        ILayerZeroEndpointV2.Origin memory oAck = ILayerZeroEndpointV2.Origin({
            srcEid: DST, sender: bytes32(uint256(uint160(address(escrow)))), nonce: 1
        });
        vm.prank(address(epSrc));
        filler.lzReceive(oAck, bytes32(uint256(2)), ack, address(0), "");
        assertEq(bluai.balanceOf(alice), 69.3e18);
        assertEq(bluai.balanceOf(bob), 0.7e18);
        assertEq(bluai.balanceOf(address(filler)), 0);
    }

    function testLzWrongAskRefunds() public {
        _mintAlice(100e18);
        uint256 id = _list(100e18, 70e18);
        bluai.mint(bob, 1e18);
        vm.startPrank(bob);
        bluai.approve(address(filler), 1e18);
        filler.fill{value: 0.01 ether}(id, DST, address(bluai), 1e18, alice);
        vm.stopPrank();

        bytes memory fillMsg = abi.encode(uint8(1), id, bob, uint256(1e18), alice);
        ILayerZeroEndpointV2.Origin memory oFill = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(filler)))), nonce: 1
        });
        vm.prank(address(epDst));
        escrow.lzReceive{value: 0.01 ether}(oFill, bytes32(uint256(1)), fillMsg, address(0), "");
        assertEq(oft.balanceOf(alice), 0);
        assertEq(oft.balanceOf(address(escrow)), 100e18);

        bytes memory refund = abi.encode(uint8(3), id);
        ILayerZeroEndpointV2.Origin memory oRef = ILayerZeroEndpointV2.Origin({
            srcEid: DST, sender: bytes32(uint256(uint160(address(escrow)))), nonce: 1
        });
        vm.prank(address(epSrc));
        filler.lzReceive(oRef, bytes32(uint256(3)), refund, address(0), "");
        assertEq(bluai.balanceOf(bob), 1e18);
        assertEq(oft.balanceOf(address(escrow)), 100e18);
    }

    function testC1CannotRedeemThroughOFT() public {
        _mintAlice(1e18);
        vm.prank(alice);
        vm.expectRevert(LeafClosedOFT.ExitViaMarketOnly.selector);
        oft.sendTo{value: 0.01 ether}(SRC, alice, 1e18);
    }

    function _srcOrigin() internal view returns (ILayerZeroEndpointV2.Origin memory) {
        return ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(filler)))), nonce: 1
        });
    }

    function _dstOrigin() internal view returns (ILayerZeroEndpointV2.Origin memory) {
        return ILayerZeroEndpointV2.Origin({
            srcEid: DST, sender: bytes32(uint256(uint160(address(escrow)))), nonce: 1
        });
    }

    function testBuyerAbortTooEarly() public {
        _mintAlice(100e18);
        uint256 id = _list(100e18, 70e18);
        bluai.mint(bob, 70e18);
        vm.startPrank(bob);
        bluai.approve(address(filler), 70e18);
        filler.fill{value: 0.01 ether}(id, DST, address(bluai), 70e18, alice);
        vm.expectRevert(LeafClaimFill.TooEarly.selector);
        filler.abortFill{value: 0.01 ether}(id);
        vm.stopPrank();
    }

    function testGuardianAbortRefunds() public {
        _mintAlice(100e18);
        uint256 id = _list(100e18, 70e18);
        bluai.mint(bob, 70e18);
        vm.startPrank(bob);
        bluai.approve(address(filler), 70e18);
        filler.fill{value: 0.01 ether}(id, DST, address(bluai), 70e18, alice);
        vm.stopPrank();
        vm.prank(guardian);
        filler.abortFill{value: 0.01 ether}(id);

        bytes memory abortMsg = abi.encode(uint8(4), id);
        vm.prank(address(epDst));
        escrow.lzReceive{value: 0.01 ether}(_srcOrigin(), bytes32(uint256(4)), abortMsg, address(0), "");
        assertEq(oft.balanceOf(address(escrow)), 100e18);

        bytes memory ok = abi.encode(uint8(5), id);
        vm.prank(address(epSrc));
        filler.lzReceive(_dstOrigin(), bytes32(uint256(5)), ok, address(0), "");
        assertEq(bluai.balanceOf(bob), 70e18);
        (,,,,,, LeafClaimFill.FillStatus st) = filler.fills(id);
        assertEq(uint8(st), uint8(LeafClaimFill.FillStatus.Refunded));
    }

    function testAbortLosesToFill() public {
        _mintAlice(100e18);
        uint256 id = _list(100e18, 70e18);
        bluai.mint(bob, 70e18);
        vm.startPrank(bob);
        bluai.approve(address(filler), 70e18);
        filler.fill{value: 0.01 ether}(id, DST, address(bluai), 70e18, alice);
        vm.stopPrank();

        bytes memory fillMsg = abi.encode(uint8(1), id, bob, uint256(70e18), alice);
        vm.prank(address(epDst));
        escrow.lzReceive{value: 0.01 ether}(_srcOrigin(), bytes32(uint256(1)), fillMsg, address(0), "");
        assertEq(oft.balanceOf(bob), 100e18);

        vm.prank(guardian);
        filler.abortFill{value: 0.01 ether}(id);
        bytes memory abortMsg = abi.encode(uint8(4), id);
        vm.prank(address(epDst));
        escrow.lzReceive{value: 0.01 ether}(_srcOrigin(), bytes32(uint256(4)), abortMsg, address(0), "");

        bytes memory ack = abi.encode(uint8(2), id);
        vm.prank(address(epSrc));
        filler.lzReceive(_dstOrigin(), bytes32(uint256(2)), ack, address(0), "");
        assertEq(bluai.balanceOf(alice), 69.3e18);
        assertEq(bluai.balanceOf(bob), 0.7e18);
    }

    function testRetryAckPaysSeller() public {
        _mintAlice(100e18);
        uint256 id = _list(100e18, 70e18);
        bluai.mint(bob, 70e18);
        vm.startPrank(bob);
        bluai.approve(address(filler), 70e18);
        filler.fill{value: 0.01 ether}(id, DST, address(bluai), 70e18, alice);
        vm.stopPrank();

        bytes memory fillMsg = abi.encode(uint8(1), id, bob, uint256(70e18), alice);
        vm.prank(address(epDst));
        escrow.lzReceive{value: 0.01 ether}(_srcOrigin(), bytes32(uint256(1)), fillMsg, address(0), "");
        assertEq(bluai.balanceOf(address(filler)), 70e18);

        escrow.retryAck{value: 0.01 ether}(id);
        bytes memory ack = abi.encode(uint8(2), id);
        vm.prank(address(epSrc));
        filler.lzReceive(_dstOrigin(), bytes32(uint256(2)), ack, address(0), "");
        assertEq(bluai.balanceOf(alice), 69.3e18);
        vm.prank(address(epSrc));
        filler.lzReceive(_dstOrigin(), bytes32(uint256(3)), ack, address(0), "");
        assertEq(bluai.balanceOf(alice), 69.3e18);
    }

    function testLateFillAfterAbortRefunds() public {
        _mintAlice(100e18);
        uint256 id = _list(100e18, 70e18);
        bluai.mint(bob, 70e18);
        vm.startPrank(bob);
        bluai.approve(address(filler), 70e18);
        filler.fill{value: 0.01 ether}(id, DST, address(bluai), 70e18, alice);
        vm.stopPrank();
        vm.prank(guardian);
        filler.abortFill{value: 0.01 ether}(id);
        bytes memory abortMsg = abi.encode(uint8(4), id);
        vm.prank(address(epDst));
        escrow.lzReceive{value: 0.01 ether}(_srcOrigin(), bytes32(uint256(4)), abortMsg, address(0), "");
        bytes memory ok = abi.encode(uint8(5), id);
        vm.prank(address(epSrc));
        filler.lzReceive(_dstOrigin(), bytes32(uint256(5)), ok, address(0), "");
        assertEq(bluai.balanceOf(bob), 70e18);

        bytes memory fillMsg = abi.encode(uint8(1), id, bob, uint256(70e18), alice);
        vm.prank(address(epDst));
        escrow.lzReceive{value: 0.01 ether}(_srcOrigin(), bytes32(uint256(6)), fillMsg, address(0), "");
        assertEq(oft.balanceOf(address(escrow)), 100e18);
        bytes memory refund = abi.encode(uint8(3), id);
        vm.prank(address(epSrc));
        filler.lzReceive(_dstOrigin(), bytes32(uint256(7)), refund, address(0), "");
        assertEq(bluai.balanceOf(bob), 70e18);
    }
}
