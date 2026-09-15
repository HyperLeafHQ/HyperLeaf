// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OtcRemoteLock} from "src/otc/OtcRemoteLock.sol";
import {OtcClaim} from "src/otc/OtcClaim.sol";
import {OtcSameChainMailbox} from "src/otc/OtcSameChainMailbox.sol";

contract MockUsdc is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

/// @dev Stand-in for Leaf Market fillLocal: leaf in, want in, swap.
contract MockLeafMarket {
    function fill(address leaf, address want, address seller, address buyer, uint256 leafAmt, uint256 wantAmt) external {
        ERC20(leaf).transferFrom(seller, buyer, leafAmt);
        ERC20(want).transferFrom(buyer, seller, wantAmt);
    }
}

contract OtcRemoteClaimTest is Test {
    MockUsdc arcUsdc;
    MockUsdc hevmUsdc;
    OtcRemoteLock lock;
    OtcClaim claim;
    OtcSameChainMailbox box;
    MockLeafMarket market;
    address owner = address(0xA11CE);
    address seller = address(0x5E11);
    address buyer = address(0xB0B);

    function setUp() public {
        arcUsdc = new MockUsdc();
        hevmUsdc = new MockUsdc();
        lock = new OtcRemoteLock(owner, arcUsdc);
        claim = new OtcClaim(owner, "HyperLeaf Arc USDC", "hArcUSDC", 6);
        box = new OtcSameChainMailbox(owner);
        market = new MockLeafMarket();
        vm.startPrank(owner);
        box.setEnds(address(lock), address(claim));
        lock.setMailbox(address(box));
        claim.setMailbox(address(box));
        vm.stopPrank();
        arcUsdc.mint(seller, 1_000e6);
        hevmUsdc.mint(buyer, 2_000e6);
    }

    function testDepositMintsOneToOne() public {
        vm.startPrank(seller);
        arcUsdc.approve(address(lock), 100e6);
        lock.deposit(100e6, seller);
        vm.stopPrank();
        assertEq(claim.balanceOf(seller), 100e6);
        assertEq(claim.decimals(), 6);
        assertEq(lock.totalLocked(), 100e6);
        assertEq(arcUsdc.balanceOf(address(lock)), 100e6);
    }

    function testRedeemReleasesSource() public {
        vm.startPrank(seller);
        arcUsdc.approve(address(lock), 40e6);
        lock.deposit(40e6, seller);
        claim.redeem(40e6, seller);
        vm.stopPrank();
        assertEq(claim.totalSupply(), 0);
        assertEq(lock.totalLocked(), 0);
        assertEq(arcUsdc.balanceOf(seller), 1_000e6);
    }

    function testMarketFillThenBuyerRedeemsOnArc() public {
        vm.startPrank(seller);
        arcUsdc.approve(address(lock), 50e6);
        lock.deposit(50e6, seller);
        claim.approve(address(market), 50e6);
        vm.stopPrank();
        vm.startPrank(buyer);
        hevmUsdc.approve(address(market), 95e6);
        market.fill(address(claim), address(hevmUsdc), seller, buyer, 50e6, 95e6);
        claim.redeem(50e6, buyer);
        vm.stopPrank();
        assertEq(hevmUsdc.balanceOf(seller), 95e6);
        assertEq(arcUsdc.balanceOf(buyer), 50e6);
        assertEq(claim.totalSupply(), 0);
        assertEq(lock.totalLocked(), 0);
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
