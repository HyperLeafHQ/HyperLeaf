// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NestVaultC1} from "../src/NestVaultC1.sol";
import {HNest} from "../src/HNest.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockVotingEscrow} from "./mocks/MockVotingEscrow.sol";
import {MockHevAdapter} from "./mocks/MockHevAdapter.sol";
import {MockMerkleAirdrop} from "./mocks/MockMerkleAirdrop.sol";
import {HyperEVMAddresses} from "../src/config/HyperEVMAddresses.sol";

contract NestVaultC1Test is Test {
    MockERC20 nest;
    MockERC20 hype;
    MockVotingEscrow ve;
    MockHevAdapter adapter;
    MockMerkleAirdrop merkle;
    NestVaultC1 vault;
    HNest hNest;

    address gate = makeAddr("gate");
    address alice = makeAddr("alice");
    address keeper = makeAddr("keeper");
    address guardian = makeAddr("guardian");
    address feeRecipient = makeAddr("fee");
    address stranger = makeAddr("stranger");

    function setUp() public {
        nest = new MockERC20("NEST", "NEST");
        hype = new MockERC20("HYPE", "HYPE");
        ve = new MockVotingEscrow(address(nest));
        merkle = new MockMerkleAirdrop(address(hype));
        MockHevAdapter tmp = new MockHevAdapter(address(ve), address(hype), address(0));
        vault = new NestVaultC1(
            address(nest),
            address(ve),
            address(hype),
            address(tmp),
            feeRecipient,
            keeper,
            guardian,
            1_000_000 ether,
            address(0),
            address(merkle)
        );
        tmp.setVault(address(vault));
        adapter = tmp;
        hNest = vault.hNest();
        vault.setDepositGate(gate);
        vault.setDepositsEnabled(true);

        nest.mint(gate, 10_000 ether);
        vm.prank(gate);
        nest.approve(address(vault), type(uint256).max);
    }

    function _deposit(uint256 amt) internal {
        vm.prank(gate);
        vault.deposit(amt);
    }

    function testMerkleAddressPinned() public pure {
        assertEq(HyperEVMAddresses.NEST_HYPE_MERKLE, 0x33afCe556508A39181a0609288c3E93611a00905);
    }

    function testDepositOnlyViaGate() public {
        nest.mint(alice, 100 ether);
        vm.startPrank(alice);
        nest.approve(address(vault), type(uint256).max);
        vm.expectRevert(NestVaultC1.OnlyDepositGate.selector);
        vault.deposit(10 ether);
        vm.stopPrank();
        _deposit(100 ether);
        assertEq(hNest.balanceOf(gate), 100 ether);
        assertEq(vault.totalNestLocked(), 100 ether);
        uint256 id = vault.getVeNFTId(0);
        assertTrue(vault.inHev(id));
        assertTrue(ve.getNftState(id).locked.isPermanentLocked);
    }

    function testNoRedeemFunction() public {
        // requestWithdraw must not exist on C1.
        (bool ok,) = address(vault).call(abi.encodeWithSignature("requestWithdraw(uint256)", 1));
        assertFalse(ok);
    }

    function testYieldThenNewDepositNotOneToOne() public {
        _deposit(100 ether);
        uint256 id = vault.getVeNFTId(0);
        adapter.seedLockedShare(id, 10 ether);
        vm.prank(keeper);
        vault.bookVerifiedYield();
        uint256 supply = hNest.totalSupply();
        uint256 locked = vault.totalNestLocked();
        assertGt(locked, 100 ether);
        _deposit(100 ether);
        uint256 minted = hNest.balanceOf(gate) - 100 ether;
        assertEq(minted, (100 ether * supply) / locked);
        assertTrue(minted < 100 ether);
    }

    function testMerkleClaimTakesOnePercent() public {
        _deposit(100 ether);
        hype.mint(address(merkle), 1 ether);
        merkle.setEntitlement(address(vault), 1 ether);
        bytes32[] memory proof;
        vm.prank(stranger);
        vault.claimMerkle(proof, 1 ether);
        uint256 fee = 1 ether / 100;
        assertEq(hype.balanceOf(feeRecipient), fee);
        vm.prank(gate);
        vault.claimResidualHype();
        assertEq(hype.balanceOf(gate), 1 ether - fee);
    }

    function testThirdPartyClaimThenAnyoneSettlesFee() public {
        _deposit(100 ether);
        hype.mint(address(merkle), 1 ether);
        merkle.setEntitlement(address(vault), 1 ether);
        bytes32[] memory proof;
        vm.prank(stranger);
        merkle.claim(proof, address(vault), 1 ether);
        assertEq(hype.balanceOf(feeRecipient), 0);
        vm.prank(alice);
        vault.settleInboundHype();
        assertEq(hype.balanceOf(feeRecipient), 1 ether / 100);
    }

    function testEnableDepositsNeedsGate() public {
        MockHevAdapter tmp = new MockHevAdapter(address(ve), address(hype), address(0));
        NestVaultC1 v2 = new NestVaultC1(
            address(nest),
            address(ve),
            address(hype),
            address(tmp),
            feeRecipient,
            keeper,
            guardian,
            0,
            address(0),
            address(merkle)
        );
        vm.expectRevert(NestVaultC1.GateRequired.selector);
        v2.setDepositsEnabled(true);
    }

    function testEnableDepositsNeedsMerkleAndAdapter() public {
        MockHevAdapter tmp = new MockHevAdapter(address(ve), address(hype), address(0));
        NestVaultC1 v2 = new NestVaultC1(
            address(nest),
            address(ve),
            address(hype),
            address(0),
            feeRecipient,
            keeper,
            guardian,
            0,
            address(0),
            address(0)
        );
        v2.setDepositGate(gate);
        vm.expectRevert(NestVaultC1.MerkleNotSet.selector);
        v2.setDepositsEnabled(true);
        v2.setHevAdapter(address(tmp));
        v2.setMerkleAirdrop(address(merkle));
        v2.setDepositsEnabled(true);
        assertTrue(v2.depositsEnabled());
    }

    function testPendingIncludesUnsettledMerkle() public {
        _deposit(100 ether);
        hype.mint(address(merkle), 1 ether);
        merkle.setEntitlement(address(vault), 1 ether);
        bytes32[] memory proof;
        vm.prank(stranger);
        merkle.claim(proof, address(vault), 1 ether);
        uint256 expectedNet = 1 ether - (1 ether / 100);
        assertEq(vault.pendingResidualHype(gate), expectedNet);
        vm.prank(gate);
        vault.claimResidualHype();
        assertEq(hype.balanceOf(gate), expectedNet);
        assertEq(hype.balanceOf(feeRecipient), 1 ether / 100);
    }

    function testPauseDoesNotBlockSettle() public {
        _deposit(100 ether);
        vm.prank(guardian);
        vault.pause();
        hype.mint(address(merkle), 1 ether);
        merkle.setEntitlement(address(vault), 1 ether);
        bytes32[] memory proof;
        vault.claimMerkle(proof, 1 ether);
        assertEq(hype.balanceOf(feeRecipient), 1 ether / 100);
    }

    function testZeroSupplyLeavesHypeUnaccounted() public {
        hype.mint(address(vault), 1 ether);
        vault.settleInboundHype();
        assertEq(hype.balanceOf(feeRecipient), 0);
        _deposit(100 ether);
        assertEq(hype.balanceOf(feeRecipient), 1 ether / 100);
    }

    function testNewDepositDoesNotTakePriorUnsettledHype() public {
        _deposit(100 ether);
        vm.prank(gate);
        hNest.transfer(alice, 100 ether);

        hype.mint(address(vault), 1 ether);
        uint256 net = 1 ether - (1 ether / 100);

        _deposit(100 ether);

        assertEq(vault.pendingResidualHype(alice), net);
        assertEq(vault.pendingResidualHype(gate), 0);
        vm.prank(alice);
        vault.claimResidualHype();
        assertEq(hype.balanceOf(alice), net);
        assertEq(hype.balanceOf(gate), 0);
    }
}
