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

        gate = new EpochHNestGate(address(vault), address(hype), keeper, guardian, feeRecipient);
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

    function _end(uint256 epochId) internal view returns (uint256 end) {
        (, end,,,,,,,) = gate.epochs(epochId);
    }

    function _rollAllocateFinalize(uint256 epochId, uint256 hypeAmt) internal {
        uint256 end = _end(epochId);
        if (block.timestamp < end) vm.warp(end);
        vm.prank(keeper);
        gate.rollEpoch();
        if (hypeAmt > 0) {
            vm.prank(keeper);
            gate.allocateHype(epochId, hypeAmt);
        }
        vm.warp(end + gate.HYPE_FINALIZE_DELAY());
        vm.prank(keeper);
        gate.finalizeHype(epochId);
    }

    function test_EpochUsesFixed7dAnd8dClaimBoundary() public view {
        (uint256 start, uint256 end, uint256 claimableAt,,,,,,) = gate.epochs(0);
        assertEq(gate.NEST_EPOCH_LENGTH(), 7 days);
        assertEq(gate.HNEST_MINT_DELAY(), 8 days);
        assertEq(end - (start / 7 days) * 7 days, 7 days);
        assertGe(claimableAt, start + 8 days);
    }

    function test_DirectVaultDepositBlockedWhenGateSet() public {
        vm.prank(alice);
        nest.approve(address(vault), type(uint256).max);
        vm.prank(alice);
        vm.expectRevert(NestVault.OnlyDepositGate.selector);
        vault.deposit(1 ether);
    }

    function test_OwnerCannotClearOrRotateDepositGate() public {
        vm.expectRevert(NestVault.ZeroAddress.selector);
        vault.setDepositGate(address(0));
        vm.expectRevert(NestVault.DepositGateFrozen.selector);
        vault.setDepositGate(address(0xBEEF));
    }

    function test_RollCannotMoveBeforeFull7dEvenWhenEpochEmpty() public {
        uint256 end = _end(0);
        vm.warp(end - 1);
        vm.prank(keeper);
        vm.expectRevert(EpochHNestGate.EpochStillOpen.selector);
        gate.rollEpoch();

        vm.warp(end);
        vm.prank(keeper);
        gate.rollEpoch();
        assertEq(gate.currentEpochId(), 1);
    }

    function test_RollStillWorksAfterAllocate() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        uint256 end = _end(0);
        vm.warp(end);
        vm.prank(keeper);
        gate.allocateHype(0, 1 ether);
        vm.prank(keeper);
        gate.rollEpoch();
        assertEq(gate.currentEpochId(), 1);
        vm.warp(end + gate.HYPE_FINALIZE_DELAY());
        vm.prank(keeper);
        gate.finalizeHype(0);
    }

    function test_AllocateZeroCannotSealWeek() public {
        vm.prank(alice);
        gate.deposit(50 ether);
        uint256 end = _end(0);
        vm.warp(end);
        vm.prank(keeper);
        vm.expectRevert(EpochHNestGate.ZeroAmount.selector);
        gate.allocateHype(0, 0);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(EpochHNestGate.FinalizeTooEarly.selector, end + 1 days));
        gate.finalizeHype(0);
    }

    function test_ZeroHypeEpochStillReleasesHnestAfterDelay() public {
        vm.prank(alice);
        gate.deposit(50 ether);
        _rollAllocateFinalize(0, 0);

        uint256 unlock = gate.userClaimableAt(0, alice);
        if (block.timestamp < unlock) vm.warp(unlock);
        vm.prank(alice);
        gate.claim(0);
        assertEq(hNest.balanceOf(alice), 50 ether);
        assertEq(hype.balanceOf(alice), 0);
    }

    function test_HnestStaysStandardErc20AfterClaim() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        assertEq(hNest.balanceOf(alice), 0);

        _rollAllocateFinalize(0, 10 ether);
        uint256 unlock = gate.userClaimableAt(0, alice);
        if (block.timestamp < unlock) vm.warp(unlock);
        vm.prank(alice);
        gate.claim(0);

        assertEq(hNest.balanceOf(alice), 100 ether);
        vm.prank(alice);
        hNest.transfer(dexBuyer, 40 ether);
        assertEq(hNest.balanceOf(dexBuyer), 40 ether);
    }

    function test_NewDepositHypeGoesToDepositorNotDexBuyer() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        _rollAllocateFinalize(0, 10 ether);

        uint256 unlock = gate.userClaimableAt(0, alice);
        if (block.timestamp < unlock) vm.warp(unlock);
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
        (uint256 start, uint256 end,,,,,,,) = gate.epochs(0);
        vm.warp(end - 1 days);
        vm.prank(alice);
        gate.deposit(100 ether);

        _rollAllocateFinalize(0, 10 ether);
        uint256 unlock = gate.userClaimableAt(0, alice);
        assertGe(unlock, (end - 1 days) + 8 days);

        vm.warp(unlock - 1);
        vm.prank(alice);
        vm.expectRevert();
        gate.claim(0);

        vm.warp(unlock);
        vm.prank(alice);
        gate.claim(0);
        assertEq(hNest.balanceOf(alice), 100 ether);
        start;
    }

    function test_SecondDepositExtendsUserDelayToLatestDeposit() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        uint256 firstUnlock = gate.userClaimableAt(0, alice);

        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        gate.deposit(50 ether);
        uint256 secondUnlock = gate.userClaimableAt(0, alice);
        assertGt(secondUnlock, firstUnlock);

        _rollAllocateFinalize(0, 15 ether);
        vm.warp(secondUnlock - 1);
        vm.prank(alice);
        vm.expectRevert();
        gate.claim(0);

        vm.warp(secondUnlock);
        vm.prank(alice);
        gate.claim(0);
        assertEq(hNest.balanceOf(alice), 150 ether);
    }

    function test_TwoDepositorsSplitNetHypeProRata() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        vm.prank(bob);
        gate.deposit(300 ether);
        _rollAllocateFinalize(0, 40 ether);

        uint256 unlock = gate.userClaimableAt(0, alice);
        uint256 unlockB = gate.userClaimableAt(0, bob);
        if (unlockB > unlock) unlock = unlockB;
        vm.warp(unlock);
        vm.prank(alice);
        gate.claim(0);
        vm.prank(bob);
        gate.claim(0);

        assertEq(hype.balanceOf(feeRecipient), 0.4 ether);
        assertEq(hype.balanceOf(alice), (100 ether * 39.6 ether) / 400 ether);
        assertEq(hype.balanceOf(bob), (300 ether * 39.6 ether) / 400 ether);
    }

    function test_GuardianCanPauseGateAndOwnerUnpauses() public {
        vm.prank(guardian);
        gate.pause();
        vm.prank(alice);
        vm.expectRevert();
        gate.deposit(1 ether);
        vm.prank(guardian);
        vm.expectRevert();
        gate.unpause();
        gate.unpause();
        vm.prank(alice);
        gate.deposit(1 ether);
    }
}
