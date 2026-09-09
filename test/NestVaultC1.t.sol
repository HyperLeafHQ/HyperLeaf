// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NestVaultC1} from "../src/NestVaultC1.sol";
import {HNest} from "../src/HNest.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockVotingEscrow} from "./mocks/MockVotingEscrow.sol";
import {MockHevAdapter} from "./mocks/MockHevAdapter.sol";

contract NestVaultC1Test is Test {
    MockERC20 nest;
    MockERC20 hype;
    MockVotingEscrow ve;
    MockHevAdapter adapter;
    NestVaultC1 vault;
    HNest hNest;

    address alice = makeAddr("alice");
    address keeper = makeAddr("keeper");
    address guardian = makeAddr("guardian");
    address feeRecipient = makeAddr("fee");
    address migrationRecipient = makeAddr("migration");

    function setUp() public {
        nest = new MockERC20("NEST", "NEST");
        hype = new MockERC20("HYPE", "HYPE");
        ve = new MockVotingEscrow(address(nest));
        adapter = new MockHevAdapter(address(ve), address(hype), address(0));
        vault = new NestVaultC1(
            address(nest), address(ve), address(hype), address(adapter), feeRecipient, keeper, guardian, 1_000_000 ether, address(0)
        );
        adapter.setVault(address(vault));
        hNest = vault.hNest();
        vault.setDepositsEnabled(true);
        nest.mint(alice, 1_000 ether);
        vm.prank(alice);
        nest.approve(address(vault), type(uint256).max);
    }

    function test_DepositMintsTransferableHNestAndLocksFullPrincipal() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        assertEq(hNest.balanceOf(alice), 100 ether);
        assertEq(vault.totalNestLocked(), 100 ether);
        assertEq(vault.totalVeNFTs(), 1);
        uint256 tokenId = vault.getVeNFTId(0);
        assertTrue(vault.inHev(tokenId));
        assertEq(vault.nestPrincipal(tokenId), 100 ether);
        assertEq(nest.balanceOf(address(vault)), 0);
    }

    function test_RedemptionAlwaysDisabled() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        vm.expectRevert(NestVaultC1.RedemptionDisabled.selector);
        vault.requestWithdraw(1 ether);
        assertEq(hNest.balanceOf(alice), 100 ether);
        assertEq(vault.totalNestLocked(), 100 ether);
    }

    function test_HNestRemainsNormalTransferableErc20() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        address bob = makeAddr("bob");
        vm.prank(alice);
        hNest.transfer(bob, 40 ether);
        assertEq(hNest.balanceOf(alice), 60 ether);
        assertEq(hNest.balanceOf(bob), 40 ether);
        assertEq(vault.totalNestLocked(), 100 ether);
    }

    function test_NonOwnerCannotDetachOrTransferVeNFT() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        uint256 tokenId = vault.getVeNFTId(0);
        vm.prank(alice);
        vm.expectRevert();
        vault.ownerDetachVeNFT(tokenId);
        vm.prank(alice);
        vm.expectRevert();
        vault.ownerTransferVeNFT(tokenId, migrationRecipient);
    }

    function test_OwnerDetachAndTransferVeNFT() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        uint256 tokenId = vault.getVeNFTId(0);
        vm.expectRevert(NestVaultC1.NFTStillAttached.selector);
        vault.ownerTransferVeNFT(tokenId, migrationRecipient);
        vault.ownerDetachVeNFT(tokenId);
        assertFalse(vault.inHev(tokenId));
        assertFalse(ve.getNftState(tokenId).isAttached);
        vault.ownerTransferVeNFT(tokenId, migrationRecipient);
        assertEq(ve.ownerOf(tokenId), migrationRecipient);
    }

    function test_OwnerWithdrawsUnderlyingAfterUnlock() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        uint256 tokenId = vault.getVeNFTId(0);
        vault.ownerDetachVeNFT(tokenId);
        vm.warp(block.timestamp + 26 weeks + 1);
        uint256 before = nest.balanceOf(migrationRecipient);
        vault.ownerWithdrawVeNFT(tokenId, migrationRecipient);
        assertEq(nest.balanceOf(migrationRecipient), before + 100 ether);
        assertEq(vault.totalNestLocked(), 0);
        assertEq(vault.totalVeNFTs(), 0);
    }
}
