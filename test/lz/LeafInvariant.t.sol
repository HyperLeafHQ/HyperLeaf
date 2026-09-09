// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafRedeemQueue} from "src/lz/LeafRedeemQueue.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract InvToken is ERC20 {
    constructor() ERC20("IN", "IN") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
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

/// @dev Stateful L: supply ≤ locked ≤ cap. Donations do not mint. 1% fee is paid out.
contract LeafLHandler is Test {
    LeafOFTAdapter public adapter;
    LeafOFT public oft;
    InvToken public inner;
    address public feeTo;
    uint32 public constant SRC = 30184;
    uint32 public constant DST = 30367;
    uint256 public feePaid;

    constructor(LeafOFTAdapter adapter_, LeafOFT oft_, InvToken inner_, address feeTo_) {
        adapter = adapter_;
        oft = oft_;
        inner = inner_;
        feeTo = feeTo_;
        vm.deal(address(this), 100 ether);
    }

    function deposit(uint256 amt) external {
        amt = bound(amt, 1, 20e18);
        if (amt > adapter.maxPerTx()) amt = adapter.maxPerTx();
        if (adapter.totalLocked() + amt > adapter.depositCap()) return;
        inner.mint(address(this), amt);
        inner.approve(address(adapter), amt);
        try adapter.sendTo{value: 0.01 ether}(DST, address(this), amt) {
            bytes memory payload = adapter.encodeBridge(bytes32(uint256(uint160(address(this)))), amt);
            ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
                srcEid: SRC, sender: bytes32(uint256(uint160(address(adapter)))), nonce: 1
            });
            vm.prank(address(oft.endpoint()));
            oft.lzReceive(origin, bytes32(uint256(1)), payload, address(0), "");
        } catch {}
    }

    function redeem(uint256 amt) external {
        uint256 bal = oft.balanceOf(address(this));
        if (bal == 0) return;
        amt = bound(amt, 1, bal);
        if (amt > oft.maxPerTx()) amt = oft.maxPerTx();
        try oft.sendTo{value: 0.01 ether}(SRC, address(this), amt) {
            bytes memory payload = oft.encodeBridge(bytes32(uint256(uint160(address(this)))), amt);
            ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
                srcEid: DST, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1
            });
            vm.prank(address(adapter.endpoint()));
            adapter.lzReceive(origin, bytes32(uint256(2)), payload, address(0), "");
        } catch {}
    }

    function donate(uint256 amt) external {
        amt = bound(amt, 1, 5e18);
        inner.mint(address(adapter), amt);
    }

    function harvest() external {
        uint256 before = inner.balanceOf(feeTo);
        adapter.harvest();
        feePaid += inner.balanceOf(feeTo) - before;
    }

    function passTime(uint256 dt) external {
        vm.warp(block.timestamp + bound(dt, 0, 2 days));
    }
}

contract LeafLInvariantTest is StdInvariant, PegReady {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    InvToken inner;
    LeafOFTAdapter adapter;
    LeafOFT oft;
    LeafLHandler handler;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);

    function setUp() public {
        epSrc = new MockEndpoint();
        epDst = new MockEndpoint();
        inner = new InvToken();
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(epSrc), owner, guardian, feeTo, 1_000e18);
        oft = new LeafOFT("hIN", "hIN", address(epDst), owner, guardian);
        adapter.setPeer(30367, address(oft));
        oft.setPeer(30184, address(adapter));
        vm.stopPrank();
        _openPair(adapter, oft, owner, 1_000e18);
        handler = new LeafLHandler(adapter, oft, inner, feeTo);
        bytes4[] memory sels = new bytes4[](5);
        sels[0] = LeafLHandler.deposit.selector;
        sels[1] = LeafLHandler.redeem.selector;
        sels[2] = LeafLHandler.donate.selector;
        sels[3] = LeafLHandler.harvest.selector;
        sels[4] = LeafLHandler.passTime.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
        targetContract(address(handler));
    }

    function invariant_supplyLeLocked() public view {
        assertLe(oft.totalSupply(), adapter.totalLocked());
        assertLe(adapter.totalLocked(), adapter.depositCap());
        assertLe(oft.totalSupply(), oft.supplyCap());
    }

    function invariant_feeNeverExceedsHarvest() public view {
        assertLe(handler.feePaid(), inner.balanceOf(feeTo));
    }
}

contract LeafC2Handler is Test {
    LeafRedeemQueue public queue;
    LeafOFT public oft;
    InvToken public inner;
    uint32 public constant SRC = 30102;
    uint32 public constant DST = 30367;
    uint256 public lastTicket;

    constructor(LeafRedeemQueue queue_, LeafOFT oft_, InvToken inner_) {
        queue = queue_;
        oft = oft_;
        inner = inner_;
        vm.deal(address(this), 100 ether);
    }

    function deposit(uint256 amt) external {
        amt = bound(amt, 1, 20e18);
        if (amt > queue.maxPerTx()) amt = queue.maxPerTx();
        if (queue.totalLocked() + amt > queue.depositCap()) return;
        inner.mint(address(this), amt);
        inner.approve(address(queue), amt);
        try queue.sendTo{value: 0.01 ether}(DST, address(this), amt) {
            bytes memory payload = queue.encodeBridge(bytes32(uint256(uint160(address(this)))), amt);
            ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
                srcEid: SRC, sender: bytes32(uint256(uint160(address(queue)))), nonce: 1
            });
            vm.prank(address(oft.endpoint()));
            oft.lzReceive(origin, bytes32(uint256(1)), payload, address(0), "");
        } catch {}
    }

    function queueRedeem(uint256 amt) external {
        uint256 bal = oft.balanceOf(address(this));
        if (bal == 0) return;
        amt = bound(amt, 1, bal);
        if (amt > oft.maxPerTx()) amt = oft.maxPerTx();
        try oft.sendTo{value: 0.01 ether}(SRC, address(this), amt) {
            bytes memory payload = oft.encodeBridge(bytes32(uint256(uint160(address(this)))), amt);
            ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
                srcEid: DST, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1
            });
            vm.prank(address(queue.endpoint()));
            queue.lzReceive(origin, bytes32(uint256(2)), payload, address(0), "");
            if (queue.nextTicketId() > 0) lastTicket = queue.nextTicketId() - 1;
        } catch {}
    }

    function claim() external {
        uint256 id = lastTicket;
        (address to,, uint64 eta, bool claimed) = queue.tickets(id);
        if (to == address(0) || claimed) return;
        if (block.timestamp < eta) vm.warp(eta);
        try queue.claim(id) {} catch {}
    }
}

contract LeafC2InvariantTest is StdInvariant, PegReady {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    InvToken inner;
    LeafRedeemQueue queue;
    LeafOFT oft;
    LeafC2Handler handler;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);

    function setUp() public {
        epSrc = new MockEndpoint();
        epDst = new MockEndpoint();
        inner = new InvToken();
        vm.startPrank(owner);
        queue = new LeafRedeemQueue(address(inner), address(epSrc), owner, guardian, feeTo, 1_000e18, 7 days);
        oft = new LeafOFT("hMET", "hMET", address(epDst), owner, guardian);
        queue.setPeer(30367, address(oft));
        oft.setPeer(30102, address(queue));
        vm.stopPrank();
        _openSrc(queue, owner, 1_000e18);
        vm.startPrank(owner);
        oft.setListingTag(keccak256("test-listing"));
        oft.setLimits(1_000e18, 1_000e18);
        oft.setSupplyCap(1_000e18);
        oft.openBridge();
        vm.stopPrank();
        handler = new LeafC2Handler(queue, oft, inner);
        bytes4[] memory sels = new bytes4[](3);
        sels[0] = LeafC2Handler.deposit.selector;
        sels[1] = LeafC2Handler.queueRedeem.selector;
        sels[2] = LeafC2Handler.claim.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
        targetContract(address(handler));
    }

    function invariant_queueCashCoversTickets() public view {
        assertGe(inner.balanceOf(address(queue)), queue.pendingTicketAssets());
        assertLe(oft.totalSupply(), queue.totalLocked());
    }
}
