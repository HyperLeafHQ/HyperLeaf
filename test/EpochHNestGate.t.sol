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

    function test_EpochUsesFixed7dAnd8dClaimBoundary() public view {
        (uint256 start, uint256 end, uint256 claimableAt,,,,,) = gate.epochs(0);
        assertEq(gate.NEST_EPOCH_LENGTH(), 7 days);
        assertEq(gate.HNEST_MINT_DELAY(), 8 days);
        assertEq(gate.SETTLEMENT_BUFFER(), 1 days);
        assertEq(end - start, 7 days);
        assertEq(claimableAt - start, 8 days);
    }

    function test_DirectVaultDepositBlockedWhenGateSet() public {
        vm.prank(alice);
        nest.approve(address(vault), type(uint256).max);
        vm.prank(alice);
        vm.expectRevert(NestVault.OnlyDepositGate.selector);
        vault.deposit(1 ether);
    }

    function test_RollCannotMoveBeforeFull7dEvenWhenEpochEmpty() public {
        vm.warp(block.timestamp + 6 days);
        vm.prank(keeper);
        vm.expectRevert(EpochHNestGate.EpochStillOpen.selector);
        gate.rollEpoch();

        vm.warp(block.timestamp + 1 days);
        vm.prank(keeper);
        gate.rollEpoch();
        assertEq(gate.currentEpochId(), 1);
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

        // Epoch has settled, but the 8-day mint delay is still active.
        vm.prank(alice);
        vm.expectRevert();
        gate.claim(0);

        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        gate.claim(0);

        assertEq(hNest.balanceOf(alice), 100 ether);
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
        vm.prank(keeper);
        gate.allocateHype(0, 10 ether);

        assertEq(hype.balanceOf(feeRecipient), 0.1 ether);

        vm.warp(1 days);
        vm.prank(alice);
        gate.claim(0);
        assertEq(hype.balanceOf(alice), 9.9 ether);

        vm.prank(alice);
        hNest.transfer(dexBuyer, 100 ether);
        assertEq(hype.balanceOf(dexBuyer), 0);

        (,,, bool claimable) = gate.pending(0, dexBuyer);
        assertFalse(claimable);
    }

    function test_LateDepositStillGetsEightDayMinimum() public {
        vm.warp(block.timestamp + 6 days);
        vm.prank(alice);
        gate.deposit(100 ether);

        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(keeper);
        gate.rollEpoch();
        vm.prank(keeper);
        gate.allocateHype(0, 10 ether);

        // Deposit was made near the end of the 7-day epoch; it must still remain
        // locked for a full 8 days from the deposit, not merely until epoch end+1d.
        vm.prank(alice);
        vm.expectRevert();
        gate.claim(0);

        vm.warp(block.timestamp + 6 days - 1);
        vm.prank(alice);
        vm.expectRevert();
        gate.claim(0);

        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(alice);
        gate.claim(0);
        assertEq(hNest.balanceOf(alice), 100 ether);
    }

    function test_SecondDepositExtendsUserDelayToLatestDeposit() public {
        vm.prank(alice);
        gate.deposit(100 ether);

        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        gate.deposit(50 ether);

        vm.warp(block.timestamp + 6 days);
        vm.prank(keeper);
        gate.rollEpoch();
        vm.prank(keeper);
        gate.allocateHype(0, 15 ether);

        vm.prank(alice);
        vm.expectRevert();
        gate.claim(0);

        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(alice);
        gate.claim(0);
        assertEq(hNest.balanceOf(alice), 150 ether);
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
        gate.allocateHype(0, 40 ether);

        vm.warp(1 days);
        vm.prank(alice);
        gate.claim(0);
        vm.prank(bob);
        gate.claim(0);

        assertEq(hype.balanceOf(feeRecipient), 0.4 ether);
        assertEq(hype.balanceOf(alice), (100 ether * 39.6 ether) / 400 ether);
        assertEq(hype.balanceOf(bob), (300 ether * 39.6 ether) / 400 ether);
    }

    function test_ZeroHypeEpochStillReleasesHnestAfterDelay() public {
        vm.prank(alice);
        gate.deposit(50 ether);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(keeper);
        gate.rollEpoch();
        vm.prank(keeper);
        gate.allocateHype(0, 0);

        vm.prank(alice);
        vm.expectRevert();
        gate.claim(0);

        vm.warp(1 days);
        vm.prank(alice);
        gate.claim(0);
        assertEq(hNest.balanceOf(alice), 50 ether);
        assertEq(hype.balanceOf(alice), 0);
    }
}
