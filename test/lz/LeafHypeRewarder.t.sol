// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafHypeRewarder} from "src/lz/LeafHypeRewarder.sol";
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
}

contract LeafHypeRewarderTest is PegReady {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    MockToken inner;
    MockToken whype;
    LeafOFTAdapter adapter;
    LeafOFT oft;
    LeafHypeRewarder rewarder;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address harvester = address(0x1111);
    address alice = address(0xA1);
    address bob = address(0xB0);
    bytes32 constant ID = keccak256("hkaito");
    uint32 constant DST = 30367;
    uint32 constant SRC = 30184;

    function setUp() public {
        epSrc = new MockEndpoint(SRC);
        epDst = new MockEndpoint(DST);
        inner = new MockToken("sKAITO", "sKAITO");
        whype = new MockToken("WHYPE", "WHYPE");
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(epSrc), owner, guardian, feeTo, 10_000e18);
        oft = new LeafOFT("Hyperleaf sKAITO", "hKAITO", address(epDst), owner, guardian);
        rewarder = new LeafHypeRewarder(address(whype), owner, feeTo);
        rewarder.register(ID, address(oft));
        oft.setHypeRewarder(address(rewarder), ID);
        adapter.setHarvester(harvester);
        adapter.setConverter(harvester);
        adapter.setConvertYieldToHype(true);
        adapter.setPeer(DST, address(oft));
        oft.setPeer(SRC, address(adapter));
        vm.stopPrank();
        _openPair(adapter, oft, owner, 10_000e18);
        inner.mint(alice, 100e18);
        vm.deal(alice, 1 ether);
    }

    function testNotifySplitsOnePercent() public {
        _mintAlice(100e18);
        whype.mint(address(this), 100e18);
        whype.approve(address(rewarder), 100e18);
        rewarder.notify(ID, 100e18);
        assertEq(whype.balanceOf(feeTo), 1e18);
        assertEq(rewarder.pending(ID, alice), 99e18);
        vm.prank(alice);
        rewarder.claim(ID, alice);
        assertEq(whype.balanceOf(alice), 99e18);
    }

    function testMintDoesNotStealHistoricalHype() public {
        _mintAlice(100e18);
        whype.mint(address(this), 100e18);
        whype.approve(address(rewarder), 100e18);
        rewarder.notify(ID, 100e18);
        inner.mint(bob, 100e18);
        _deliverTo(bob, 100e18);
        assertEq(rewarder.pending(ID, bob), 0);
        assertEq(rewarder.pending(ID, alice), 99e18);
    }

    function testTransferSettlesSellerKeepsHype() public {
        _mintAlice(100e18);
        whype.mint(address(this), 100e18);
        whype.approve(address(rewarder), 100e18);
        rewarder.notify(ID, 100e18);
        vm.prank(alice);
        oft.transfer(bob, 100e18);
        assertEq(rewarder.pending(ID, alice), 99e18);
        assertEq(rewarder.pending(ID, bob), 0);
    }

    function testNotifyZeroSupplyReverts() public {
        whype.mint(address(this), 10e18);
        whype.approve(address(rewarder), 10e18);
        vm.expectRevert(LeafHypeRewarder.NoSupply.selector);
        rewarder.notify(ID, 10e18);
        assertEq(whype.balanceOf(address(this)), 10e18);
    }

    function testPullYieldRejectsNonConverter() public {
        vm.startPrank(alice);
        inner.approve(address(adapter), 50e18);
        adapter.sendTo{value: 0.01 ether}(DST, alice, 50e18);
        vm.stopPrank();
        vm.prank(harvester);
        vm.expectRevert();
        adapter.pullYield(inner, harvester);
        inner.mint(address(adapter), 5e18);
        vm.prank(harvester);
        vm.expectRevert();
        adapter.pullYield(inner, harvester);
        assertEq(inner.balanceOf(address(adapter)), 55e18);
    }

    function testStrangerCannotPull() public {
        inner.mint(address(adapter), 1e18);
        vm.prank(alice);
        vm.expectRevert();
        adapter.pullYield(inner, alice);
    }

    function testConvertRedeemIsOneToOne() public {
        vm.startPrank(alice);
        inner.approve(address(adapter), 50e18);
        adapter.sendTo{value: 0.01 ether}(DST, alice, 50e18);
        vm.stopPrank();
        inner.mint(address(adapter), 10e18);
        bytes memory payload = _msg(adapter, alice, 50e18);
        ILayerZeroEndpointV2.Origin memory origin =
            ILayerZeroEndpointV2.Origin({srcEid: DST, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1});
        vm.prank(address(epSrc));
        adapter.lzReceive(origin, bytes32(uint256(2)), payload, address(0), "");
        assertEq(inner.balanceOf(alice), 100e18);
        assertEq(inner.balanceOf(address(adapter)), 10e18);
    }

    function _mintAlice(uint256 amount) internal {
        _deliverTo(alice, amount);
    }

    function _deliverTo(address to, uint256 amount) internal {
        bytes memory payload = _msg(oft, to, amount);
        ILayerZeroEndpointV2.Origin memory origin =
            ILayerZeroEndpointV2.Origin({srcEid: SRC, sender: bytes32(uint256(uint160(address(adapter)))), nonce: 1});
        vm.prank(address(epDst));
        oft.lzReceive(origin, bytes32(uint256(1)), payload, address(0), "");
    }
}
