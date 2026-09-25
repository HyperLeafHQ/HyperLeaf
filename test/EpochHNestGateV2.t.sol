// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EpochHNestGateV2} from "../src/EpochHNestGateV2.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockNestVaultDeposit} from "./mocks/MockNestVaultDeposit.sol";

contract EpochHNestGateV2Test is Test {
    MockERC20 nest;
    MockERC20 hype;
    MockERC20 hNest;
    MockNestVaultDeposit vault;
    EpochHNestGateV2 gate;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address keeper = makeAddr("keeper");
    address guardian = makeAddr("guardian");
    address feeRecipient = makeAddr("fee");

    function setUp() public {
        nest = new MockERC20("NEST", "NEST");
        hype = new MockERC20("WHYPE", "WHYPE");
        hNest = new MockERC20("hNEST", "hNEST");
        vault = new MockNestVaultDeposit(nest, hNest, hype);
        hNest.mint(address(vault), 1_000_000 ether);
        hype.mint(address(vault), 1_000 ether);
        hype.mint(keeper, 100 ether);

        gate = new EpochHNestGateV2(address(vault), address(hype), keeper, guardian, feeRecipient);

        nest.mint(alice, 1_000 ether);
        nest.mint(bob, 1_000 ether);
        vm.prank(alice);
        nest.approve(address(gate), type(uint256).max);
        vm.prank(bob);
        nest.approve(address(gate), type(uint256).max);
        vm.prank(keeper);
        hype.approve(address(gate), type(uint256).max);
    }

    function _end(uint256 epochId) internal view returns (uint256 end) {
        (, end,,,,,,,,,,) = gate.epochs(epochId);
    }

    function _finalize(uint256 epochId) internal {
        uint256 end = _end(epochId);
        if (block.timestamp < end + gate.HYPE_FINALIZE_DELAY()) {
            vm.warp(end + gate.HYPE_FINALIZE_DELAY());
        }
        gate.finalizeHype(epochId);
    }

    function _claimReady(uint256 epochId, address user) internal {
        uint256 n = gate.trancheCount(epochId, user);
        for (uint256 i; i < n; ++i) {
            (,, uint256 unlock, bool claimed) = gate.depositTranches(epochId, user, i);
            if (claimed) continue;
            if (block.timestamp < unlock) vm.warp(unlock);
            vm.prank(user);
            gate.claimTranche(epochId, i);
        }
    }

    function test_StillEightDayGate() public view {
        (uint256 start, uint256 end, uint256 claimableAt,,,,,,,,,) = gate.epochs(0);
        assertEq(gate.NEST_EPOCH_LENGTH(), 7 days);
        assertEq(gate.HNEST_MINT_DELAY(), 8 days);
        assertGe(claimableAt, start + 8 days);
        assertEq(end - (start / 7 days) * 7 days, 7 days);
    }

    function test_ClosingResidualGoesToDepositEpochNotNextWeekNewDeposits() public {
        vm.prank(alice);
        gate.deposit(88 ether);

        uint256 end0 = _end(0);
        vm.warp(end0);
        vault.creditResidual(address(gate), 10 ether);
        gate.rollEpoch();

        (,,,,,,,, uint256 allocated0,,,) = gate.epochs(0);
        assertEq(allocated0, 10 ether);

        vm.prank(bob);
        gate.deposit(100 ether);
        assertEq(gate.pendingGrowth(0, alice), 0);
        assertEq(gate.pendingGrowth(1, bob), 0);

        _finalize(0);
        _claimReady(0, alice);
        assertEq(hype.balanceOf(alice), 10 ether);
        assertEq(hype.balanceOf(bob), 0);
    }

    function test_MidEpochGrowthGoesToCarryOnly() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        uint256 end0 = _end(0);
        vm.warp(end0);
        gate.rollEpoch();

        vm.prank(bob);
        gate.deposit(100 ether);

        vault.creditResidual(address(gate), 4 ether);
        gate.syncGrowthHype();

        assertEq(gate.pendingGrowth(0, alice), 4 ether);
        assertEq(gate.pendingGrowth(1, bob), 0);

        _finalize(0);
        _claimReady(0, alice);
        assertEq(hype.balanceOf(alice), 4 ether);
        assertEq(hype.balanceOf(bob), 0);
    }

    function test_ClaimInWeekTwoStillOnlyGetsDepositEpochAllocate() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        uint256 end0 = _end(0);
        vm.warp(end0);
        vault.creditResidual(address(gate), 8 ether);
        gate.rollEpoch();

        vm.prank(bob);
        gate.deposit(100 ether);
        uint256 end1 = _end(1);
        vm.warp(end1);
        vault.creditResidual(address(gate), 20 ether);
        gate.rollEpoch();

        (,,,,,,,, uint256 allocated0,,,) = gate.epochs(0);
        (,,,,,,,, uint256 allocated1,,,) = gate.epochs(1);
        assertEq(allocated0, 8 ether);
        assertEq(allocated1, 20 ether);

        _finalize(0);
        _claimReady(0, alice);
        assertEq(hype.balanceOf(alice), 8 ether);

        _finalize(1);
        _claimReady(1, bob);
        assertEq(hype.balanceOf(bob), 20 ether);
    }

    function test_Issue106DilutionDoesNotHappen() public {
        vm.prank(alice);
        gate.deposit(88 ether);
        uint256 end0 = _end(0);
        vm.warp(end0);
        vault.creditResidual(address(gate), 2.253 ether);
        gate.rollEpoch();

        vm.prank(bob);
        gate.deposit(100 ether);

        vault.creditResidual(address(gate), 2.029 ether);
        gate.syncGrowthHype();

        uint256 aliceGrowth = gate.pendingGrowth(0, alice);
        uint256 bobGrowth = gate.pendingGrowth(1, bob);
        assertEq(bobGrowth, 0);
        assertApproxEqAbs(aliceGrowth, 2.029 ether, 100);

        _finalize(0);
        _claimReady(0, alice);
        assertApproxEqAbs(hype.balanceOf(alice), 2.253 ether + 2.029 ether, 100);
    }

    function test_FinalizeRequiresRollFirst() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        uint256 end0 = _end(0);
        vm.warp(end0 + gate.HYPE_FINALIZE_DELAY());
        vm.expectRevert(EpochHNestGateV2.EpochNotClosed.selector);
        gate.finalizeHype(0);

        gate.rollEpoch();
        gate.finalizeHype(0);

        vault.creditResidual(address(gate), 5 ether);
        gate.syncGrowthHype();
        (,,,,,,,, uint256 allocated0,,,) = gate.epochs(0);
        assertEq(allocated0, 0);
        assertEq(gate.pendingGrowth(0, alice), 5 ether);
    }

    function test_NoCarryResidualGoesToCurrentAllocateNotFutureCarry() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        vault.creditResidual(address(gate), 3 ether);
        gate.syncGrowthHype();

        (,,,,,,,, uint256 allocated0,,,) = gate.epochs(0);
        assertEq(allocated0, 3 ether);
        assertEq(gate.growthRemainder(), 0);

        uint256 end0 = _end(0);
        vm.warp(end0);
        gate.rollEpoch();
        vm.prank(bob);
        gate.deposit(100 ether);
        assertEq(gate.pendingGrowth(1, bob), 0);
        assertEq(gate.pendingGrowth(0, alice), 0);
    }
}
