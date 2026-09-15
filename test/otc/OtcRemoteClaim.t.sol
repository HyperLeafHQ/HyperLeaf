// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {OtcRemoteLock} from "src/otc/OtcRemoteLock.sol";
import {OtcClaim} from "src/otc/OtcClaim.sol";
import {OtcSameChainMailbox} from "src/otc/OtcSameChainMailbox.sol";
import {OtcLzMailbox} from "src/otc/OtcLzMailbox.sol";
import {LeafClaimEscrow} from "src/lz/LeafClaimEscrow.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockUsdc is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    uint32 public eid;
    address public lastRefund;
    constructor(uint32 eid_) {
        eid = eid_;
    }
    function send(MessagingParams calldata p, address refund) external payable returns (MessagingReceipt memory r) {
        lastRefund = refund;
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

contract OtcRemoteClaimTest is Test {
    MockUsdc arcUsdc;
    MockUsdc hevmUsdc;
    OtcRemoteLock lock;
    OtcClaim claim;
    OtcSameChainMailbox box;
    LeafClaimEscrow market;
    MockEndpoint epDst;
    address owner = address(0xA11CE);
    address guardian = address(0x6AAD);
    address seller = address(0x5E11);
    address buyer = address(0xB0B);

    function setUp() public {
        arcUsdc = new MockUsdc();
        hevmUsdc = new MockUsdc();
        lock = new OtcRemoteLock(owner, guardian, arcUsdc);
        claim = new OtcClaim(owner, guardian, "HyperLeaf Arc USDC", "hArcUSDC", 6);
        box = new OtcSameChainMailbox(owner);
        epDst = new MockEndpoint(30367);
        market = new LeafClaimEscrow(address(epDst), owner, guardian, address(0xFEE));
        vm.startPrank(owner);
        box.setEnds(address(lock), address(claim));
        lock.setMailbox(address(box));
        claim.setMailbox(address(box));
        market.setMarket(address(claim), address(hevmUsdc), bytes32(0), true);
        vm.stopPrank();
        arcUsdc.mint(seller, 1_000e6);
        hevmUsdc.mint(buyer, 2_000e6);
    }

    function testDepositMintsOneToOne() public {
        vm.startPrank(seller);
        arcUsdc.approve(address(lock), 100e6);
        lock.deposit(100e6, seller, seller);
        vm.stopPrank();
        assertEq(claim.balanceOf(seller), 100e6);
        assertEq(claim.decimals(), 6);
        assertEq(lock.decimals(), 6);
        assertEq(lock.totalLocked(), 100e6);
    }

    function testRedeemReleasesSource() public {
        vm.startPrank(seller);
        arcUsdc.approve(address(lock), 40e6);
        lock.deposit(40e6, seller, seller);
        claim.redeem(40e6, seller, seller);
        vm.stopPrank();
        assertEq(claim.totalSupply(), 0);
        assertEq(lock.totalLocked(), 0);
        assertEq(arcUsdc.balanceOf(seller), 1_000e6);
    }

    function testLeafMarketFillThenBuyerRedeems() public {
        vm.startPrank(seller);
        arcUsdc.approve(address(lock), 50e6);
        lock.deposit(50e6, seller, seller);
        claim.approve(address(market), 50e6);
        uint256 id = market.list(address(claim), 50e6, address(hevmUsdc), 200e6, seller, uint64(block.timestamp + 7 days));
        vm.stopPrank();
        vm.startPrank(buyer);
        hevmUsdc.approve(address(market), 200e6);
        market.fillLocal(id);
        claim.redeem(50e6, buyer, buyer);
        vm.stopPrank();
        assertEq(arcUsdc.balanceOf(buyer), 50e6);
        assertEq(hevmUsdc.balanceOf(seller), 198e6);
        assertEq(hevmUsdc.balanceOf(buyer), 2_000e6 - 200e6 + 2e6);
        assertEq(claim.totalSupply(), 0);
        assertEq(lock.totalLocked(), 0);
    }

    function testSamePartyCannotFillOwnOrder() public {
        vm.startPrank(seller);
        arcUsdc.approve(address(lock), 10e6);
        lock.deposit(10e6, seller, seller);
        claim.approve(address(market), 10e6);
        uint256 id = market.list(address(claim), 10e6, address(hevmUsdc), 20e6, seller, uint64(block.timestamp + 1 days));
        hevmUsdc.mint(seller, 20e6);
        hevmUsdc.approve(address(market), 20e6);
        vm.expectRevert(LeafClaimEscrow.SameParty.selector);
        market.fillLocal(id);
        vm.stopPrank();
    }

    function testGuardianPauseBlocksDeposit() public {
        vm.prank(guardian);
        lock.pause();
        vm.startPrank(seller);
        arcUsdc.approve(address(lock), 1e6);
        vm.expectRevert();
        lock.deposit(1e6, seller, seller);
        vm.stopPrank();
    }

    function testMaxLocked() public {
        vm.prank(owner);
        lock.setMaxLocked(10e6);
        vm.startPrank(seller);
        arcUsdc.approve(address(lock), 11e6);
        vm.expectRevert(OtcRemoteLock.Cap.selector);
        lock.deposit(11e6, seller, seller);
        lock.deposit(10e6, seller, seller);
        vm.stopPrank();
        assertEq(lock.totalLocked(), 10e6);
    }

    function _wireLz()
        internal
        returns (MockEndpoint epSrc, OtcRemoteLock lock2, OtcClaim claim2, OtcLzMailbox srcBox, OtcLzMailbox dstBox)
    {
        epSrc = new MockEndpoint(30184);
        MockEndpoint epHevm = new MockEndpoint(30367);
        lock2 = new OtcRemoteLock(owner, guardian, arcUsdc);
        claim2 = new OtcClaim(owner, guardian, "hArcUSDC", "hArcUSDC", 6);
        srcBox = new OtcLzMailbox(address(epSrc), owner, guardian, true, 6);
        dstBox = new OtcLzMailbox(address(epHevm), owner, guardian, false, 6);
        vm.startPrank(owner);
        srcBox.setLock(address(lock2));
        dstBox.setClaim(address(claim2));
        srcBox.setPeer(30367, address(dstBox));
        dstBox.setPeer(30184, address(srcBox));
        lock2.setMailbox(address(srcBox));
        claim2.setMailbox(address(dstBox));
        vm.stopPrank();
    }

    function testLzMailboxRoundTrip() public {
        (MockEndpoint epSrc, OtcRemoteLock lock2, OtcClaim claim2, OtcLzMailbox srcBox, OtcLzMailbox dstBox) = _wireLz();

        vm.deal(seller, 1 ether);
        vm.startPrank(seller);
        arcUsdc.approve(address(lock2), 25e6);
        lock2.deposit{value: 0.01 ether}(25e6, seller, seller);
        vm.stopPrank();
        assertEq(lock2.totalLocked(), 25e6);
        assertEq(claim2.totalSupply(), 0);
        assertEq(epSrc.lastRefund(), seller);

        bytes memory mintMsg = abi.encode(uint8(1), seller, uint256(25e6), uint8(6));
        vm.prank(address(dstBox.endpoint()));
        dstBox.lzReceive(
            ILayerZeroEndpointV2.Origin(30184, bytes32(uint256(uint160(address(srcBox)))), 1),
            bytes32(uint256(1)),
            mintMsg,
            address(0),
            ""
        );
        assertEq(claim2.balanceOf(seller), 25e6);

        vm.prank(seller);
        claim2.redeem{value: 0.01 ether}(25e6, seller, seller);
        assertEq(claim2.totalSupply(), 0);

        bytes memory relMsg = abi.encode(uint8(2), seller, uint256(25e6), uint8(6));
        vm.prank(address(srcBox.endpoint()));
        srcBox.lzReceive(
            ILayerZeroEndpointV2.Origin(30367, bytes32(uint256(uint160(address(dstBox)))), 1),
            bytes32(uint256(2)),
            relMsg,
            address(0),
            ""
        );
        assertEq(lock2.totalLocked(), 0);
        assertEq(arcUsdc.balanceOf(seller), 1_000e6);
    }

    function testExcessLzFeeRefundsToUser() public {
        (MockEndpoint epSrc, OtcRemoteLock lock2,,,) = _wireLz();
        vm.deal(seller, 1 ether);
        vm.startPrank(seller);
        arcUsdc.approve(address(lock2), 5e6);
        lock2.deposit{value: 0.05 ether}(5e6, seller, seller);
        vm.stopPrank();
        assertEq(epSrc.lastRefund(), seller);
        assertEq(address(lock2).balance, 0);
    }

    function testPausedMailboxBlocksInboundLz() public {
        (, OtcRemoteLock lock2, OtcClaim claim2, OtcLzMailbox srcBox, OtcLzMailbox dstBox) = _wireLz();
        vm.deal(seller, 1 ether);
        vm.startPrank(seller);
        arcUsdc.approve(address(lock2), 5e6);
        lock2.deposit{value: 0.01 ether}(5e6, seller, seller);
        vm.stopPrank();

        vm.prank(guardian);
        dstBox.pause();

        bytes memory mintMsg = abi.encode(uint8(1), seller, uint256(5e6), uint8(6));
        vm.prank(address(dstBox.endpoint()));
        vm.expectRevert(Pausable.EnforcedPause.selector);
        dstBox.lzReceive(
            ILayerZeroEndpointV2.Origin(30184, bytes32(uint256(uint160(address(srcBox)))), 1),
            bytes32(uint256(1)),
            mintMsg,
            address(0),
            ""
        );
        assertEq(claim2.totalSupply(), 0);

        vm.prank(guardian);
        srcBox.pause();
        bytes memory relMsg = abi.encode(uint8(2), seller, uint256(5e6), uint8(6));
        vm.prank(address(srcBox.endpoint()));
        vm.expectRevert(Pausable.EnforcedPause.selector);
        srcBox.lzReceive(
            ILayerZeroEndpointV2.Origin(30367, bytes32(uint256(uint160(address(dstBox)))), 1),
            bytes32(uint256(2)),
            relMsg,
            address(0),
            ""
        );
        assertEq(lock2.totalLocked(), 5e6);
    }

    function testMismatchedDecimalsRejected() public {
        OtcClaim claim18 = new OtcClaim(owner, guardian, "bad", "bad", 18);
        OtcSameChainMailbox box2 = new OtcSameChainMailbox(owner);
        vm.prank(owner);
        vm.expectRevert(OtcSameChainMailbox.DecimalMismatch.selector);
        box2.setEnds(address(lock), address(claim18));

        MockEndpoint epHevm = new MockEndpoint(30367);
        OtcLzMailbox dstBox = new OtcLzMailbox(address(epHevm), owner, guardian, false, 6);
        vm.prank(owner);
        vm.expectRevert(OtcLzMailbox.DecimalMismatch.selector);
        dstBox.setClaim(address(claim18));

        OtcLzMailbox dst18 = new OtcLzMailbox(address(epHevm), owner, guardian, false, 18);
        vm.prank(owner);
        dst18.setClaim(address(claim18));
        bytes memory mintMsg = abi.encode(uint8(1), seller, uint256(1e6), uint8(6));
        // no peer yet — OnlyPeer. set a dummy peer then pause not needed
        vm.prank(owner);
        dst18.setPeer(30184, address(0xBEEF));
        vm.prank(address(epHevm));
        vm.expectRevert(OtcLzMailbox.DecimalMismatch.selector);
        dst18.lzReceive(
            ILayerZeroEndpointV2.Origin(30184, bytes32(uint256(uint160(address(0xBEEF)))), 1),
            bytes32(uint256(1)),
            mintMsg,
            address(0),
            ""
        );
    }

    function testStrangerCannotMint() public {
        vm.prank(seller);
        vm.expectRevert(OtcClaim.NotMailbox.selector);
        claim.mint(seller, 1e6);
    }

    function testMailboxOneShot() public {
        vm.prank(owner);
        vm.expectRevert(OtcRemoteLock.AlreadySet.selector);
        lock.setMailbox(address(1));
    }
}
