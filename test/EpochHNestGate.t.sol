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
    address newFeeRecipient = makeAddr("newFee");

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
        (, end,,,,,,,,,) = gate.epochs(epochId);
    }

    function _rollAllocateFinalize(uint256 epochId, uint256 hypeAmt) internal {
        uint256 end = _end(epochId);
        if (block.timestamp < end) vm.warp(end);
        gate.rollEpoch();
        if (hypeAmt > 0) {
            vm.prank(keeper);
            gate.allocateHype(epochId, hypeAmt);
        }
        vm.warp(end + gate.HYPE_FINALIZE_DELAY());
        gate.finalizeHype(epochId);
    }

    function _claimWhenReady(uint256 epochId, address user) internal {
        uint256 unlock = gate.userClaimableAt(epochId, user);
        if (block.timestamp < unlock) vm.warp(unlock);
        vm.prank(user);
        gate.claim(epochId);
    }

    function test_EpochUsesFixed7dAnd8dClaimBoundary() public view {
        (uint256 start, uint256 end, uint256 claimableAt,,,,,,,,) = gate.epochs(0);
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

    function test_AnyoneCanFinalizeAfterDelay() public {
        vm.prank(alice);
        gate.deposit(50 ether);
        uint256 end = _end(0);
        vm.warp(end + gate.HYPE_FINALIZE_DELAY());
        gate.finalizeHype(0);
        _claimWhenReady(0, alice);
        assertEq(hNest.balanceOf(alice), 50 ether);
    }

    function test_RollStillWorksAfterAllocate() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        uint256 end = _end(0);
        vm.warp(end);
        vm.prank(keeper);
        gate.allocateHype(0, 1 ether);
        gate.rollEpoch();
        assertEq(gate.currentEpochId(), 1);
    }

    function test_PermissionlessRollAndAutoRollKeepDepositsLive() public {
        uint256 end0 = _end(0);
        vm.warp(end0);
        gate.rollEpoch();
        assertEq(gate.currentEpochId(), 1);

        vm.prank(alice);
        gate.deposit(100 ether);
        assertEq(gate.currentEpochId(), 1);

        uint256 end1 = _end(1);
        vm.warp(end1);
        vm.prank(bob);
        gate.deposit(100 ether);
        assertEq(gate.currentEpochId(), 2);
    }

    function test_EpochFeeAndRecipientUseSnapshots() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        _rollAllocateFinalize(0, 10 ether);

        gate.setFee(500);
        gate.setFeeRecipient(newFeeRecipient);

        (
            ,
            ,
            ,
            ,
            ,
            uint256 snapshot,
            address recipientSnapshot,
            uint256 allocated,
            uint256 feeTaken,
            ,
        ) = gate.epochs(0);
        assertEq(snapshot, 100);
        assertEq(recipientSnapshot, feeRecipient);
        assertEq(hype.balanceOf(newFeeRecipient), 0);
        assertEq(hype.balanceOf(feeRecipient), 0.1 ether);
        assertEq(allocated, 9.9 ether);
        assertEq(feeTaken, 0.1 ether);
    }

    function test_FeeChangeAfterOpenDoesNotAffectAllocate() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        uint256 end = _end(0);
        vm.warp(end);
        gate.setFee(500);
        gate.setFeeRecipient(newFeeRecipient);
        vm.prank(keeper);
        gate.allocateHype(0, 10 ether);
        assertEq(hype.balanceOf(feeRecipient), 0.1 ether);
        assertEq(hype.balanceOf(newFeeRecipient), 0);
    }

    function test_ZeroHypeEpochStillReleasesHnestAfterDelay() public {
        vm.prank(alice);
        gate.deposit(50 ether);
        _rollAllocateFinalize(0, 0);
        _claimWhenReady(0, alice);
        assertEq(hNest.balanceOf(alice), 50 ether);
        assertEq(hype.balanceOf(alice), 0);
    }

    function test_HnestStaysStandardErc20AfterClaim() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        _rollAllocateFinalize(0, 10 ether);
        _claimWhenReady(0, alice);
        vm.prank(alice);
        hNest.transfer(dexBuyer, 40 ether);
        assertEq(hNest.balanceOf(dexBuyer), 40 ether);
    }

    function test_NewDepositHypeGoesToDepositorNotDexBuyer() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        _rollAllocateFinalize(0, 10 ether);
        _claimWhenReady(0, alice);
        assertEq(hype.balanceOf(alice), 9.9 ether);
        vm.prank(alice);
        hNest.transfer(dexBuyer, 100 ether);
        assertEq(hype.balanceOf(dexBuyer), 0);
    }

    function test_LateDepositStillGetsEightDayMinimum() public {
        (, uint256 end,,,,,,,,,) = gate.epochs(0);
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

    function test_VaultResidualHypeIsSeparatedAndProRataAcrossGateCustody() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        vm.prank(bob);
        gate.deposit(300 ether);

        hype.mint(address(vault), 10 ether);
        _rollAllocateFinalize(0, 0);
        _claimWhenReady(0, alice);
        assertEq(hype.balanceOf(alice), 2.5 ether);

        _claimWhenReady(0, bob);
        assertEq(hype.balanceOf(bob), 7.5 ether);
        assertEq(hype.balanceOf(address(gate)), 0);
        assertEq(vault.pendingResidualHype(address(gate)), 0);
    }

    function test_LaterEpochDepositDoesNotInheritEarlierVaultResidual() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        hype.mint(address(vault), 10 ether);
        gate.syncVaultResidualHype();
        assertGt(gate.vaultResidualIndex(), 0);

        uint256 end0 = _end(0);
        vm.warp(end0);
        gate.rollEpoch();
        vm.prank(bob);
        gate.deposit(100 ether);
        assertEq(gate.pendingVaultResidual(1, bob), 0);
        assertEq(gate.pendingVaultResidual(0, alice), 10 ether);

        vm.warp(end0 + gate.HYPE_FINALIZE_DELAY());
        gate.finalizeHype(0);
        _claimWhenReady(0, alice);
        assertEq(hype.balanceOf(alice), 10 ether);
        assertEq(hype.balanceOf(bob), 0);
    }

    function test_MultipleDepositsSameEpochAccrueAtCheckpoint() public {
        vm.prank(alice);
        gate.deposit(100 ether);
        hype.mint(address(vault), 10 ether);
        gate.syncVaultResidualHype();
        vm.prank(alice);
        gate.deposit(100 ether);
        assertEq(gate.pendingVaultResidual(0, alice), 10 ether);

        _rollAllocateFinalize(0, 0);
        _claimWhenReady(0, alice);
        assertEq(hype.balanceOf(alice), 10 ether);
        assertEq(hNest.balanceOf(alice), 200 ether);
    }
}
