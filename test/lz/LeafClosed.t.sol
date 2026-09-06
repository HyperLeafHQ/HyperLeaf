// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {LeafRedeemQueue} from "src/lz/LeafRedeemQueue.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockToken is ERC20 {
    constructor() ERC20("BLUAI", "BLUAI") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    uint32 public eid;

    constructor(uint32 eid_) {
        eid = eid_;
    }

    function send(MessagingParams calldata _params, address) external payable returns (MessagingReceipt memory r) {
        r.guid = keccak256(abi.encode(_params, block.number));
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

    function deliver(address oapp, Origin calldata origin, bytes calldata message) external {
        LeafOFT(payable(oapp)).lzReceive(origin, bytes32(uint256(1)), message, address(this), "");
    }

    function deliverLockbox(address oapp, Origin calldata origin, bytes calldata message) external {
        LeafInboundLockbox(payable(oapp)).lzReceive(origin, bytes32(uint256(1)), message, address(this), "");
    }

    function deliverQueue(address oapp, Origin calldata origin, bytes calldata message) external {
        LeafRedeemQueue(payable(oapp)).lzReceive(origin, bytes32(uint256(1)), message, address(this), "");
    }
}

contract LeafClosedTest is Test {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    MockToken token;
    LeafInboundLockbox box;
    LeafClosedOFT oft;
    LeafRedeemQueue queue;
    LeafOFT queuedOft;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address user = address(0xCAFE);
    uint32 constant SRC_EID = 30102;
    uint32 constant DST_EID = 30367;
    uint32 constant LOCK_4Y = 4 * 365 days;

    function setUp() public {
        epSrc = new MockEndpoint(SRC_EID);
        epDst = new MockEndpoint(DST_EID);
        token = new MockToken();
        vm.startPrank(owner);
        box = new LeafInboundLockbox(address(token), address(epSrc), owner, guardian, feeTo, 1_000e18);
        oft = new LeafClosedOFT("Hyperliquid BLUAI 4Year", "BLUAI4Y", LOCK_4Y, address(epDst), owner, guardian);
        queue = new LeafRedeemQueue(address(token), address(epSrc), owner, guardian, feeTo, 1_000e18, 7 days);
        queuedOft = new LeafOFT("Hyperliquid VIRTUAL 30D", "VIRTUAL30D", address(epDst), owner, guardian);
        box.setPeer(DST_EID, address(oft));
        oft.setPeer(SRC_EID, address(box));
        queue.setPeer(DST_EID, address(queuedOft));
        queuedOft.setPeer(SRC_EID, address(queue));
        vm.stopPrank();
        token.mint(user, 100e18);
        vm.deal(user, 1 ether);
    }

    function testClosedTicker() public view {
        assertEq(oft.name(), "Hyperliquid BLUAI 4Year");
        assertEq(oft.symbol(), "BLUAI4Y");
        assertEq(oft.lockSeconds(), LOCK_4Y);
    }

    function testC1MintsAndBlocksRedeem() public {
        vm.startPrank(user);
        token.approve(address(box), 10e18);
        box.sendTo{value: 0.01 ether}(DST_EID, user, 10e18);
        vm.stopPrank();

        bytes memory payload = abi.encode(bytes32(uint256(uint160(user))), uint256(10e18));
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC_EID, sender: bytes32(uint256(uint160(address(box)))), nonce: 1
        });
        epDst.deliver(address(oft), origin, payload);
        assertEq(oft.balanceOf(user), 10e18);

        vm.prank(user);
        vm.expectRevert(LeafClosedOFT.ExitViaMarketOnly.selector);
        oft.sendTo{value: 0.01 ether}(SRC_EID, user, 1e18);

        ILayerZeroEndpointV2.Origin memory back = ILayerZeroEndpointV2.Origin({
            srcEid: DST_EID, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1
        });
        vm.expectRevert(LeafInboundLockbox.InboundOnly.selector);
        epSrc.deliverLockbox(address(box), back, payload);
        assertEq(token.balanceOf(address(box)), 10e18);
        assertEq(token.balanceOf(feeTo), 0);
    }

    function testC1HarvestTakesOnePercentStaysAsBacking() public {
        testC1MintsAndBlocksRedeem();
        token.mint(address(box), 100e18);
        box.harvest();
        assertEq(token.balanceOf(feeTo), 1e18);
        assertEq(token.balanceOf(address(box)), 109e18);
        box.harvest();
        assertEq(token.balanceOf(feeTo), 1e18);
        assertEq(token.balanceOf(address(box)), 109e18);
    }

    function testC2QueueThenClaim() public {
        vm.startPrank(user);
        token.approve(address(queue), 8e18);
        queue.sendTo{value: 0.01 ether}(DST_EID, user, 8e18);
        vm.stopPrank();
        bytes memory payload = abi.encode(bytes32(uint256(uint160(user))), uint256(8e18));
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC_EID, sender: bytes32(uint256(uint160(address(queue)))), nonce: 1
        });
        epDst.deliver(address(queuedOft), origin, payload);
        assertEq(queuedOft.balanceOf(user), 8e18);

        vm.prank(user);
        queuedOft.sendTo{value: 0.01 ether}(SRC_EID, user, 3e18);
        bytes memory back = abi.encode(bytes32(uint256(uint160(user))), uint256(3e18));
        ILayerZeroEndpointV2.Origin memory o2 = ILayerZeroEndpointV2.Origin({
            srcEid: DST_EID, sender: bytes32(uint256(uint160(address(queuedOft)))), nonce: 1
        });
        epSrc.deliverQueue(address(queue), o2, back);
        (address to, uint256 amount, uint64 eta, bool claimed) = queue.tickets(0);
        assertEq(to, user);
        assertEq(amount, 3e18);
        assertFalse(claimed);

        vm.expectRevert(LeafRedeemQueue.NotMature.selector);
        queue.claim(0);

        vm.warp(uint256(eta));
        queue.claim(0);
        assertEq(token.balanceOf(user), 95e18);
        assertEq(token.balanceOf(feeTo), 0);
        (, , , bool claimedAfter) = queue.tickets(0);
        assertTrue(claimedAfter);
    }

    function testC2HarvestThenProRataTicket() public {
        vm.startPrank(user);
        token.approve(address(queue), 8e18);
        queue.sendTo{value: 0.01 ether}(DST_EID, user, 8e18);
        vm.stopPrank();
        bytes memory payload = abi.encode(bytes32(uint256(uint160(user))), uint256(8e18));
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC_EID, sender: bytes32(uint256(uint160(address(queue)))), nonce: 1
        });
        epDst.deliver(address(queuedOft), origin, payload);

        token.mint(address(queue), 100e18);
        queue.harvest();
        assertEq(token.balanceOf(feeTo), 1e18);

        vm.prank(user);
        queuedOft.sendTo{value: 0.01 ether}(SRC_EID, user, 8e18);
        bytes memory back = abi.encode(bytes32(uint256(uint160(user))), uint256(8e18));
        ILayerZeroEndpointV2.Origin memory o2 = ILayerZeroEndpointV2.Origin({
            srcEid: DST_EID, sender: bytes32(uint256(uint160(address(queuedOft)))), nonce: 1
        });
        epSrc.deliverQueue(address(queue), o2, back);
        (, uint256 amount, uint64 eta,) = queue.tickets(0);
        assertEq(amount, 107e18);

        vm.warp(uint256(eta));
        queue.claim(0);
        assertEq(token.balanceOf(user), 92e18 + 107e18);
        assertEq(token.balanceOf(feeTo), 1e18);
    }

    function testC2HarvestDoesNotTouchQueuedTickets() public {
        vm.startPrank(user);
        token.approve(address(queue), 8e18);
        queue.sendTo{value: 0.01 ether}(DST_EID, user, 8e18);
        vm.stopPrank();
        bytes memory payload = abi.encode(bytes32(uint256(uint160(user))), uint256(8e18));
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC_EID, sender: bytes32(uint256(uint160(address(queue)))), nonce: 1
        });
        epDst.deliver(address(queuedOft), origin, payload);

        vm.prank(user);
        queuedOft.sendTo{value: 0.01 ether}(SRC_EID, user, 3e18);
        bytes memory back = abi.encode(bytes32(uint256(uint160(user))), uint256(3e18));
        ILayerZeroEndpointV2.Origin memory o2 = ILayerZeroEndpointV2.Origin({
            srcEid: DST_EID, sender: bytes32(uint256(uint160(address(queuedOft)))), nonce: 1
        });
        epSrc.deliverQueue(address(queue), o2, back);
        (, uint256 ticketAmt, uint64 eta,) = queue.tickets(0);
        assertEq(ticketAmt, 3e18);
        assertEq(queue.pendingTicketAssets(), 3e18);

        token.mint(address(queue), 100e18);
        queue.harvest();
        assertEq(token.balanceOf(feeTo), 1e18);
        (, uint256 ticketAfter,,) = queue.tickets(0);
        assertEq(ticketAfter, 3e18);

        vm.warp(uint256(eta));
        queue.claim(0);
        assertEq(token.balanceOf(user), 95e18);
    }
}
