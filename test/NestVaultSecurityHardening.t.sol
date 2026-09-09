// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NestVault} from "../src/NestVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockVotingEscrow} from "./mocks/MockVotingEscrow.sol";
import {MockHevAdapter} from "./mocks/MockHevAdapter.sol";

contract NestVaultSecurityHardeningTest is Test {
    MockERC20 nest;
    MockERC20 hype;
    MockVotingEscrow ve;
    MockHevAdapter adapter;
    NestVault vault;

    address alice = makeAddr("alice");
    address keeper = makeAddr("keeper");
    address guardian = makeAddr("guardian");
    address feeRecipient = makeAddr("fee");

    function setUp() public {
        nest = new MockERC20("NEST", "NEST");
        hype = new MockERC20("HYPE", "HYPE");
        ve = new MockVotingEscrow(address(nest));
        adapter = new MockHevAdapter(address(ve), address(hype), address(0));
        vault = new NestVault(
            address(nest),
            address(ve),
            address(hype),
            address(adapter),
            feeRecipient,
            keeper,
            guardian,
            1_000_000 ether,
            address(0)
        );
        adapter.setVault(address(vault));
        vault.setDepositsEnabled(true);

        nest.mint(alice, 10_000 ether);
        nest.mint(keeper, 10_000 ether);
        vm.prank(alice);
        nest.approve(address(vault), type(uint256).max);
        vm.prank(keeper);
        nest.approve(address(vault), type(uint256).max);
    }

    function test_HevAdapterCannotBeSwappedWhileLive() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        MockHevAdapter replacement = new MockHevAdapter(address(ve), address(hype), address(vault));
        vm.expectRevert(NestVault.HevAdapterChangeWhileLive.selector);
        vault.setHevAdapter(address(replacement));
    }

    function test_PendingWithdrawAccountingIsConstantTimeAndBatchBounded() public {
        for (uint256 i = 0; i < 40; ++i) {
            vm.prank(alice);
            vault.deposit(1 ether);
            vm.prank(alice);
            vault.requestWithdraw(1 ether);
        }
        assertEq(vault.pendingWithdrawNest(), 40 ether);

        vm.prank(keeper);
        vault.topUpIdle(40 ether);
        vm.prank(keeper);
        vault.processWithdrawQueue();

        (,, uint256 pendingRequests) = vault.withdrawQueueStatus();
        assertEq(pendingRequests, 8);
        assertEq(vault.pendingWithdrawNest(), 8 ether);
    }
}
