// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafHypeRewarder} from "src/lz/LeafHypeRewarder.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
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
        oft.setHypeRewarder(address(rewarder), ID);
        rewarder.register(ID, address(oft));
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
        uint256 before = rewarder.pending(ID, alice);
        vm.prank(alice);
        oft.transfer(bob, 100e18);
        assertEq(before, 99e18);
        assertEq(rewarder.pending(ID, alice), before);
        assertEq(rewarder.pending(ID, bob), 0);
    }

    function testPartialTransferKeepsSellerHype() public {
        _mintAlice(100e18);
        _notify(100e18);
        vm.prank(alice);
        oft.transfer(bob, 40e18);
        assertEq(rewarder.pending(ID, alice), 99e18);
        assertEq(rewarder.pending(ID, bob), 0);
        _notify(100e18);
        // next harvest: 60/40 split of 99. seller still has the old 99.
        assertEq(rewarder.pending(ID, alice), 99e18 + 59.4e18);
        assertEq(rewarder.pending(ID, bob), 39.6e18);
    }

    /// @dev Claim-market / AMM escrow is just another address. Historical HYPE
    ///      stays with the seller. The board must not mint a second claim token.
    function testEscrowHopDoesNotMovePendingHype() public {
        address market = address(0xCAFE);
        _mintAlice(100e18);
        _notify(100e18);
        uint256 sellerDue = rewarder.pending(ID, alice);
        vm.prank(alice);
        oft.transfer(market, 100e18);
        assertEq(rewarder.pending(ID, alice), sellerDue);
        assertEq(rewarder.pending(ID, market), 0);
        vm.prank(market);
        oft.transfer(bob, 100e18);
        assertEq(rewarder.pending(ID, alice), sellerDue);
        assertEq(rewarder.pending(ID, market), 0);
        assertEq(rewarder.pending(ID, bob), 0);
        vm.prank(alice);
        rewarder.claim(ID, alice);
        assertEq(whype.balanceOf(alice), sellerDue);
        assertEq(whype.balanceOf(bob), 0);
        assertEq(whype.balanceOf(market), 0);
    }

    function testNotifyZeroSupplyReverts() public {
        whype.mint(address(this), 10e18);
        whype.approve(address(rewarder), 10e18);
        vm.expectRevert(LeafHypeRewarder.NoSupply.selector);
        rewarder.notify(ID, 10e18);
        assertEq(whype.balanceOf(address(this)), 10e18);
    }

    function testNotifyDustDoesNotTrapHype() public {
        _mintAlice(100e18);
        whype.mint(address(this), 1);
        whype.approve(address(rewarder), 1);
        vm.expectRevert(LeafHypeRewarder.DustNotify.selector);
        rewarder.notify(ID, 1);
        assertEq(whype.balanceOf(address(this)), 1);
        uint256 floor = rewarder.minNotify(ID);
        assertGt(floor, 1);
        whype.mint(address(this), floor);
        whype.approve(address(rewarder), floor);
        rewarder.notify(ID, floor);
        assertGt(rewarder.pending(ID, alice), 0);
    }

    function testRegisterRequiresOftBind() public {
        vm.startPrank(owner);
        LeafOFT other = new LeafOFT("x", "x", address(epDst), owner, guardian);
        vm.expectRevert(LeafHypeRewarder.ListingMismatch.selector);
        rewarder.register(keccak256("no"), address(other));
        other.setHypeRewarder(address(rewarder), keccak256("wrong"));
        vm.expectRevert(LeafHypeRewarder.ListingMismatch.selector);
        rewarder.register(keccak256("no"), address(other));
        vm.expectRevert(LeafOFT.ListingIdFrozen.selector);
        other.setHypeRewarder(address(rewarder), keccak256("nope"));
        bytes32 id2 = keccak256("other");
        LeafOFT ok = new LeafOFT("y", "y", address(epDst), owner, guardian);
        ok.setHypeRewarder(address(rewarder), id2);
        rewarder.register(id2, address(ok));
        vm.expectRevert(LeafHypeRewarder.AlreadyRegistered.selector);
        rewarder.register(id2, address(ok));
        vm.expectRevert(LeafHypeRewarder.TokenAlreadyRegistered.selector);
        rewarder.register(keccak256("third"), address(ok));
        vm.stopPrank();
    }


    function testBrokenRewarderDoesNotBrickTransfer() public {
        _mintAlice(10e18);
        RevertingRewarder bad = new RevertingRewarder();
        vm.prank(owner);
        oft.setHypeRewarder(address(0), ID);
        vm.prank(alice);
        oft.transfer(bob, 10e18);
        vm.prank(owner);
        vm.expectRevert(LeafOFT.RewarderFrozen.selector);
        oft.setHypeRewarder(address(bad), ID);
        assertEq(oft.balanceOf(bob), 10e18);
        assertEq(oft.balanceOf(alice), 0);
    }

    function testPairShareStaysUnclaimed() public {
        _mintAlice(70e18);
        _deliverTo(address(0xCAFE), 30e18);
        whype.mint(address(this), 100e18);
        whype.approve(address(rewarder), 100e18);
        rewarder.notify(ID, 100e18);
        assertEq(whype.balanceOf(feeTo), 1e18);
        assertEq(rewarder.pending(ID, alice), 69.3e18);
        assertEq(rewarder.pending(ID, address(0xCAFE)), 29.7e18);
        vm.prank(alice);
        rewarder.claim(ID, alice);
        assertEq(whype.balanceOf(alice), 69.3e18);
        assertEq(whype.balanceOf(address(rewarder)), 29.7e18);
    }

    function testNotifyMintClaimCloses() public {
        _mintAlice(50e18);
        _notify(10e18);
        _deliverTo(bob, 50e18);
        assertEq(rewarder.pending(ID, bob), 0);
        _notify(10e18);
        uint256 a = rewarder.pending(ID, alice);
        uint256 b = rewarder.pending(ID, bob);
        assertEq(a, 9.9e18 + 4.95e18);
        assertEq(b, 4.95e18);
        vm.prank(alice);
        rewarder.claim(ID, alice);
        vm.prank(bob);
        rewarder.claim(ID, bob);
        assertEq(whype.balanceOf(alice) + whype.balanceOf(bob) + whype.balanceOf(feeTo), 20e18);
        assertEq(whype.balanceOf(address(rewarder)), 0);
    }

    function _notify(uint256 amount) internal {
        whype.mint(address(this), amount);
        whype.approve(address(rewarder), amount);
        rewarder.notify(ID, amount);
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

    function testOwnerCannotPullToEoa() public {
        inner.mint(address(adapter), 1e18);
        vm.prank(owner);
        vm.expectRevert(LeafYieldFee.BadConverter.selector);
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

contract RevertingRewarder {
    fallback() external {
        revert("down");
    }
}

