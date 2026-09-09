// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NestVault} from "../src/NestVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockVotingEscrow} from "./mocks/MockVotingEscrow.sol";
import {MockHevAdapter} from "./mocks/MockHevAdapter.sol";

contract NestVaultAdminMigrationTest is Test {
    MockERC20 nest;
    MockERC20 hype;
    MockVotingEscrow ve;
    MockHevAdapter adapter;
    NestVault vault;

    address alice = makeAddr("alice");
    address keeper = makeAddr("keeper");
    address feeRecipient = makeAddr("fee");
    address recipient = makeAddr("recipient");

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
            address(0),
            0,
            address(0)
        );
        tmp.setVault(address(vault));
        adapter = tmp;
        vault.setDepositsEnabled(true);

        nest.mint(alice, 10_001 ether);
        vm.prank(alice);
        nest.approve(address(vault), type(uint256).max);
    }

    function test_OwnerCanTransferVaultVeNFTForMigration() public {
        vm.prank(alice);
        vault.deposit(10_001 ether);

        uint256 tokenId = vault.getVeNFTId(0);
        assertEq(ve.ownerOf(tokenId), address(vault));
        assertTrue(vault.inHev(tokenId));
        assertTrue(adapter.deposited(tokenId));

        vault.ownerTransferVeNFT(tokenId, recipient);

        assertEq(ve.ownerOf(tokenId), recipient);
        assertFalse(vault.inHev(tokenId));
        assertEq(adapter.deposited(tokenId), false);
        assertEq(vault.totalVeNFTs(), 0);
    }

    function test_NonOwnerCannotTransferVaultVeNFT() public {
        vm.prank(alice);
        vault.deposit(1 ether);
        uint256 tokenId = vault.getVeNFTId(0);

        vm.prank(alice);
        vm.expectRevert();
        vault.ownerTransferVeNFT(tokenId, recipient);
    }
}
