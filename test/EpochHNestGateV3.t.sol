// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EpochHNestGateV3} from "../src/EpochHNestGateV3.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockNestVaultDeposit} from "./mocks/MockNestVaultDeposit.sol";

contract EpochHNestGateV3Test is Test {
    MockERC20 nest;
    MockERC20 hype;
    MockERC20 hNest;
    MockNestVaultDeposit vault;
    EpochHNestGateV3 gate;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address keeper = makeAddr("keeper");
    address guardian = makeAddr("guardian");
    address stranger = makeAddr("stranger");

    function setUp() public {
        nest = new MockERC20("NEST", "NEST");
        hype = new MockERC20("WHYPE", "WHYPE");
        hNest = new MockERC20("hNEST", "hNEST");
        vault = new MockNestVaultDeposit(nest, hNest, hype);
        hNest.mint(address(vault), 1_000_000 ether);
        hype.mint(address(vault), 1_000 ether);
        hype.mint(keeper, 100 ether);

        EpochHNestGateV3 impl = new EpochHNestGateV3();
        gate = EpochHNestGateV3(
            address(
                new ERC1967Proxy(
                    address(impl),
                    abi.encodeCall(EpochHNestGateV3.initialize, (address(this), address(vault), address(hype), keeper, guardian))
                )
            )
        );

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
        (, end,,,,,,,) = gate.epochs(epochId);
    }

    function _rollTo(uint256 epochId) internal {
        while (gate.currentEpochId() < epochId) {
            vm.warp(_end(gate.currentEpochId()));
            gate.rollEpoch();
        }
    }

    function _book(uint256 epochId, uint256 amount) internal {
        if (block.timestamp < _end(epochId)) vm.warp(_end(epochId));
        vm.prank(keeper);
        gate.bookEpoch(epochId, amount);
    }

    function _finalize(uint256 epochId) internal {
        uint256 earliest = _end(epochId) + gate.HYPE_FINALIZE_DELAY();
        if (block.timestamp < earliest) vm.warp(earliest);
        gate.finalizeHype(epochId);
    }

    function test_eightDayDelayUnchanged() public view {
        (uint256 start, uint256 end, uint256 claimableAt,,,,,,) = gate.epochs(0);
        assertEq(gate.HNEST_MINT_DELAY(), 8 days);
        assertEq(gate.NEST_EPOCH_LENGTH(), 7 days);
        assertGe(claimableAt, start + 8 days);
        assertEq(end, (start / 7 days) * 7 days + 7 days);
    }

    function test_acceptance_bookOpenEpochReverts() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        vm.prank(keeper);
        gate.fundUnassigned(1 ether);
        vm.prank(keeper);
        vm.expectRevert(EpochHNestGateV3.EpochStillOpen.selector);
        gate.bookEpoch(0, 1 ether);
    }

    function test_acceptance_secondBookReverts() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        vm.prank(keeper);
        gate.fundUnassigned(2 ether);
        _book(0, 1 ether);
        vm.prank(keeper);
        vm.expectRevert(EpochHNestGateV3.AlreadyBooked.selector);
        gate.bookEpoch(0, 1 ether);
    }

    function test_acceptance_bookAfterFinalizeReverts() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        vm.prank(keeper);
        gate.fundUnassigned(2 ether);
        _book(0, 1 ether);
        _rollTo(1);
        _finalize(0);
        vm.prank(keeper);
        vm.expectRevert(EpochHNestGateV3.HypeAlreadyFinal.selector);
        gate.bookEpoch(0, 1 ether);
    }

    function test_acceptance_nonKeeperReverts() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        vm.warp(_end(0));
        vm.prank(stranger);
        vm.expectRevert(EpochHNestGateV3.NotKeeper.selector);
        gate.bookEpoch(0, 1 ether);
        vm.expectRevert(EpochHNestGateV3.NotKeeper.selector);
        gate.bookEpoch(0, 1 ether);
    }

    function test_acceptance_lateListBooksEachEpoch() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        _rollTo(2);

        vm.prank(keeper);
        gate.fundUnassigned(10 ether);
        _book(0, 4 ether);
        _book(1, 6 ether);

        (,,,,,, uint256 pot0,,) = gate.epochs(0);
        (,,,,,, uint256 pot1,,) = gate.epochs(1);
        assertEq(pot0, 4 ether, "week 0 is alice's new-deposit pot");
        assertEq(pot1, 0, "week 1 has no new deposit");
        assertEq(gate.growthAccounted(1) + gate.unassignedHype(), 6 ether, "week 1 stays growth plus dust");
        assertLt(gate.unassignedHype(), 1e12);
    }

    function test_acceptance_claimedUserKeepsCustodyShare() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        vm.prank(bob);
        gate.deposit(10 ether);

        vm.prank(keeper);
        gate.fundUnassigned(1 ether);
        _book(0, 1 ether);
        _rollTo(1);
        _finalize(0);

        (,, uint256 unlock,,,) = gate.depositTranches(0, alice, 0);
        vm.warp(unlock);
        vm.prank(alice);
        gate.claimTranche(0, 0);

        uint256 end1 = _end(1);
        vm.warp(end1);
        gate.rollEpoch();

        uint256 alicePts = gate.tranchePoints(1, 0, alice, 0);
        uint256 bobPts = gate.tranchePoints(1, 0, bob, 0);
        assertGt(bobPts, alicePts, "bob stayed the whole week");
        assertEq(alicePts + bobPts, gate.carryPointSupply(1));

        vm.prank(keeper);
        gate.fundUnassigned(8 ether);
        _book(1, 8 ether);

        uint256 aliceBefore = hype.balanceOf(alice);
        vm.prank(alice);
        gate.claimGrowth(0, 0);
        uint256 aliceGain = hype.balanceOf(alice) - aliceBefore;

        vm.prank(bob);
        gate.claimGrowth(0, 0);
        uint256 bobGain = hype.balanceOf(bob);

        uint256 per = gate.growthPerPoint(1);
        assertEq(aliceGain, (alicePts * per) / 1e18);
        assertEq(bobGain, (bobPts * per) / 1e18);
        assertEq(aliceGain + bobGain + gate.unassignedHype(), 8 ether);
        assertGt(aliceGain, 0);
        assertLt(aliceGain, bobGain);
    }

    function test_laterEpochNewDepositsDoNotPayEarlierUser() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        _rollTo(1);
        vm.prank(bob);
        gate.deposit(10 ether);

        vm.prank(keeper);
        gate.fundUnassigned(4 ether);
        _book(0, 4 ether);
        _finalize(0);

        (,, uint256 unlock,,,) = gate.depositTranches(0, alice, 0);
        if (block.timestamp < unlock) vm.warp(unlock);
        uint256 before = hype.balanceOf(alice);
        vm.prank(alice);
        gate.claimTranche(0, 0);
        assertEq(hype.balanceOf(alice) - before, 4 ether, "deposit week only, later week not booked yet");

        vm.prank(keeper);
        gate.fundUnassigned(10 ether);
        _book(1, 10 ether);
        uint256 growthBefore = hype.balanceOf(alice);
        vm.prank(alice);
        gate.claimGrowth(0, 0);
        uint256 growth = hype.balanceOf(alice) - growthBefore;
        assertGt(growth, 0);
        assertApproxEqAbs(growth, gate.growthAccounted(1), 1e12);
        (,,,,,, uint256 pot1,,) = gate.epochs(1);
        assertGt(pot1, 1 ether, "bob's deposit keeps its own pot");
        assertLt(growth + pot1, 10 ether + 1);
    }

    function test_residualSyncDoesNotPayFeeRecipient() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        vault.creditResidual(address(gate), 3 ether);
        gate.syncResidual();
        assertEq(gate.unassignedHype(), 3 ether);
        assertEq(hype.balanceOf(address(gate)), 3 ether);
    }

    function test_upgradeKeepsBookedEpoch() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        vm.prank(keeper);
        gate.fundUnassigned(2 ether);
        _book(0, 2 ether);

        GateV3Step2 step2 = new GateV3Step2();
        gate.upgradeToAndCall(address(step2), "");
        assertEq(GateV3Step2(address(gate)).versionTag(), 2);
        (,,,,,, uint256 pot,,) = gate.epochs(0);
        assertEq(pot, 2 ether);
        assertEq(gate.nestIn(0, alice), 10 ether);
    }

    function test_p2_tinyGrowthDoesNotBlockFinalize() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        _rollTo(1);
        vm.prank(bob);
        gate.deposit(10 ether);

        vm.warp(_end(1));
        vm.prank(keeper);
        gate.fundUnassigned(2);
        vm.prank(keeper);
        gate.bookEpoch(1, 2);

        assertTrue(gate.weekBooked(1));
        assertEq(gate.growthPerPoint(1), 0);
        assertEq(gate.growthAccounted(1), 0);
        (,,,,,, uint256 pot,,) = gate.epochs(1);
        assertGt(pot, 0);
        assertEq(gate.unassignedHype(), 2 - pot);

        gate.rollEpoch();
        _finalize(1);
        (,,,,,,, bool closed, bool hypeFinal) = gate.epochs(1);
        assertTrue(closed);
        assertTrue(hypeFinal);
    }

    function test_p2_oneWeiCarryResidualStillBooks() public {
        vm.prank(alice);
        gate.deposit(10 ether);
        _rollTo(1);
        vm.warp(_end(1));

        vm.prank(keeper);
        gate.fundUnassigned(1);
        vm.prank(keeper);
        gate.bookEpoch(1, 1);

        assertTrue(gate.weekBooked(1));
        assertEq(gate.growthPerPoint(1), 0);
        assertEq(gate.unassignedHype(), 1);
        assertGt(gate.carryPointSupply(1), 1e18);

        gate.rollEpoch();
        _finalize(1);
        (,,,,,,,, bool hypeFinal) = gate.epochs(1);
        assertTrue(hypeFinal);
    }
}

contract GateV3Step2 is EpochHNestGateV3 {
    function versionTag() external pure returns (uint256) {
        return 2;
    }
}
