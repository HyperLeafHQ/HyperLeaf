// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NestVault} from "../src/NestVault.sol";
import {HNest} from "../src/HNest.sol";
import {EpochHNestGate} from "../src/EpochHNestGate.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockVotingEscrow} from "./mocks/MockVotingEscrow.sol";
import {MockHevAdapter} from "./mocks/MockHevAdapter.sol";

contract EpochHNestGateTest is Test {
    MockERC20 nest;
    MockERC20 hype;
    MockVotingEscrow ve;
    MockHevAdapter adapter;
    NestVault vault;
    HNest hNest;
    EpochHNestGate gate;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address dexBuyer = makeAddr("dex");
    address keeper = makeAddr("keeper");
    address guardian = makeAddr("guardian");
    address feeRecipient = makeAddr("fee");

    function setUp() public {
        nest = new MockERC20("NEST", "NEST");
        hype = new MockERC20("HYPE", "HYPE");
        ve = new MockVotingEscrow(address(nest));
        MockHevAdapter tmp = new MockHevAdapter(address(ve), address(hype), address(0));
        vault = new NestVault(
            address(nest),
            address(ve),
            address(hype),
            address(tmp),
            feeRecipient,
            keeper,
            guardian,
            0,
            address(0)
        );
        tmp.setVault(address(vault));
        adapter = tmp;
        hNest = vault.hNest();
        vault.setDepositsEnabled(true);

        gate = new EpochHNestGate(address(vault), address(hype), keeper, feeRecipient);
        vault.setDepositGate(address(gate));

        nest.mint(alice, 1_000 ether);
        nest.mint(bob, 1_000 ether);
        hype.mint(keeper, 100 ether);
        vm.prank(alice);
        nest.approve(address(gate), type(uint256).max);
        vm.prank(bob);
        nest.approve(address(gate), type(uint256).max);
        vm.prank(keeper);
        hype.approve(address(gate), type(uint256).max);
    }

    function test_DirectVaultDepositBlockedWhenGateSet() public {
        vm.prank(alice);
        nest.approve(address(vault), type(uint256).max);
        vm.prank(alice);
        vm.expectRevert(NestVault.OnlyDepositGate.selector);
        vault.deposit(1 ether);
    }

    function test_HnestStaysStandardErc20AfterClaim() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        assertEq(hNest.balanceOf(alice), 0);
        assertEq(hNest.balanceOf(address(gate)), 100 ether);

        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(keeper);
        gate.rollEpoch();
        vm.prank(keeper);
        gate.allocateHype(0, 10 ether);

        vm.prank(alice);
        gate.claim(0);

        assertEq(hNest.balanceOf(alice), 100 ether);
        // Standard transfer — no lock, DEX can take it
        vm.prank(alice);
        hNest.transfer(dexBuyer, 40 ether);
        assertEq(hNest.balanceOf(dexBuyer), 40 ether);
        assertEq(hNest.balanceOf(alice), 60 ether);
    }

    function test_NewDepositHypeGoesToDepositorNotDexBuyer() public {
        vm.prank(alice);
        gate.deposit(100 ether);

        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(keeper);
        gate.rollEpoch();
        // 10 HYPE gross, 1% fee = 0.1, net 9.9 to alice
        vm.prank(keeper);
        gate.allocateHype(0, 10 ether);

        assertEq(hype.balanceOf(feeRecipient), 0.1 ether);

        vm.prank(alice);
        gate.claim(0);
        assertEq(hype.balanceOf(alice), 9.9 ether);

        // DEX buyer of seasoned hNEST does NOT get that week's new-deposit HYPE
        vm.prank(alice);
        hNest.transfer(dexBuyer, 100 ether);
        assertEq(hype.balanceOf(dexBuyer), 0);

        (,,, bool claimable) = gate.pending(0, dexBuyer);
        assertFalse(claimable);
    }

    function test_TwoDepositorsSplitNetHypeProRata() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        vm.prank(bob);
        gate.deposit(300 ether);

        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(keeper);
        gate.rollEpoch();
        vm.prank(keeper);
        gate.allocateHype(0, 40 ether); // fee 0.4, net 39.6

        vm.prank(alice);
        gate.claim(0);
        vm.prank(bob);
        gate.claim(0);

        assertEq(hype.balanceOf(feeRecipient), 0.4 ether);
        assertEq(hype.balanceOf(alice), (100 ether * 39.6 ether) / 400 ether);
        assertEq(hype.balanceOf(bob), (300 ether * 39.6 ether) / 400 ether);
    }

    function test_ZeroHypeEpochStillReleasesHnest() public {
        vm.prank(alice);
        gate.deposit(50 ether);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(keeper);
        gate.rollEpoch();
        vm.prank(keeper);
        gate.allocateHype(0, 0);

        vm.prank(alice);
        gate.claim(0);
        assertEq(hNest.balanceOf(alice), 50 ether);
        assertEq(hype.balanceOf(alice), 0);
    }
}
