// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NestVault} from "../src/NestVault.sol";
import {HNest} from "../src/HNest.sol";
import {HyperEVMAddresses} from "../src/config/HyperEVMAddresses.sol";
import {IVotingEscrow} from "../src/interfaces/IVotingEscrow.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockVotingEscrow} from "./mocks/MockVotingEscrow.sol";
import {MockHevAdapter} from "./mocks/MockHevAdapter.sol";

contract NestVaultTest is Test {
    MockERC20 nest;
    MockERC20 hype;
    MockVotingEscrow ve;
    MockHevAdapter adapter;
    NestVault vault;
    HNest hNest;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address keeper = makeAddr("keeper");
    address guardian = makeAddr("guardian");
    address feeRecipient = makeAddr("fee");

    uint256 constant LOCK = 26 weeks;
    uint256 constant DETACH_LOCK = 4 days;

    function setUp() public {
        nest = new MockERC20("NEST", "NEST");
        hype = new MockERC20("HYPE", "HYPE");
        ve = new MockVotingEscrow(address(nest));

        // Deploy vault with temporary zero adapter, then wire mock
        adapter = MockHevAdapter(address(0)); // placeholder

        // We need adapter address at construct — deploy adapter pointing to address(this) first then setVault
        // Pattern: deploy adapter with vault=address(0), deploy vault with adapter, then adapter.setVault
        MockHevAdapter tmp = new MockHevAdapter(address(ve), address(hype), address(0));
        vault = new NestVault(
            address(nest),
            address(ve),
            address(hype),
            address(tmp),
            feeRecipient,
            keeper,
            guardian,
            1_000_000 ether, // depositCap
            address(0) // in-constructor HNest (anvil); HyperEVM must pass pre-deployed HNest
        );
        tmp.setVault(address(vault));
        adapter = tmp;
        hNest = vault.hNest();
        vault.setDepositsEnabled(true);

        nest.mint(alice, 10_000 ether);
        nest.mint(bob, 10_000 ether);
        nest.mint(keeper, 10_000 ether);
        vm.prank(alice);
        nest.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        nest.approve(address(vault), type(uint256).max);
        vm.prank(keeper);
        nest.approve(address(vault), type(uint256).max);
    }

    function test_AddressesConstants() public pure {
        assertEq(HyperEVMAddresses.NEST, 0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035);
        assertEq(HyperEVMAddresses.VE_NEST, 0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074);
        assertEq(HyperEVMAddresses.VOTER, 0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901);
        assertEq(HyperEVMAddresses.MANAGED_NFT_MANAGER, 0x843d31e601b38F7207864457f0fB38E14441E792);
        assertEq(HyperEVMAddresses.HEV_STRATEGY, 0x96F7b8BA7580d3E510B0Fb3F0E135a743d8eb17a);
        assertEq(HyperEVMAddresses.HEV_MANAGED_TOKEN_ID, 1);
        assertEq(HyperEVMAddresses.VIRTUAL_REWARDER, 0x148405ab9F58AC790CC6cA518077deD1E6E04829);
        assertEq(HyperEVMAddresses.VE_NEST_DISTRIBUTOR, 0x22350F14c6ee70992f1bbc7498e4C291B8B7682f);
    }

    function test_DepositMintsOneToOne() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        assertEq(hNest.balanceOf(alice), 100 ether);
        assertEq(vault.totalNestLocked(), 100 ether);
        assertEq(vault.totalVeNFTs(), 1);
        assertTrue(vault.inHev(vault.getVeNFTId(0)));
        assertTrue(adapter.deposited(vault.getVeNFTId(0)));
        uint256 tokenId = vault.getVeNFTId(0);
        assertEq(vault.nestPrincipal(tokenId), 100 ether);
        // Attached: amount+end zeroed — vault must not rely on them
        IVotingEscrow.TokenState memory st = ve.getNftState(tokenId);
        assertTrue(st.isAttached);
        assertEq(uint256(int256(st.locked.amount)), 0);
        assertEq(st.locked.end, 0);
    }

    function test_DepositCap() public {
        vault.setDepositCap(50 ether);
        vm.prank(alice);
        vault.deposit(50 ether);
        vm.prank(bob);
        vm.expectRevert(NestVault.DepositCapExceeded.selector);
        vault.deposit(1 ether);
    }

    function test_HarvestSweepsResidualHypeNoVote() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 tokenId = vault.getVeNFTId(0);
        hype.mint(address(this), 10 ether);
        hype.approve(address(adapter), 10 ether);
        adapter.seedReward(tokenId, 10 ether);

        uint256 feeBps = vault.feeBps();
        uint256 expectedFee = (10 ether * feeBps) / 10_000;
        uint256 expectedNet = 10 ether - expectedFee;

        vm.prank(keeper);
        vault.harvest();

        assertEq(hype.balanceOf(feeRecipient), expectedFee);
        assertEq(vault.pendingResidualHype(alice), expectedNet);

        vm.prank(alice);
        vault.claimResidualHype();
        assertEq(hype.balanceOf(alice), expectedNet);
        assertEq(vault.pendingResidualHype(alice), 0);
    }

    function test_TransferSettlesResidualHype() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        uint256 tokenId = vault.getVeNFTId(0);
        hype.mint(address(this), 10 ether);
        hype.approve(address(adapter), 10 ether);
        adapter.seedReward(tokenId, 10 ether);

        vm.prank(keeper);
        vault.harvest();

        uint256 pendingBefore = vault.pendingResidualHype(alice);
        assertGt(pendingBefore, 0);

        // Transfer half to bob — alice should receive pending residual HYPE; bob starts clean
        vm.prank(alice);
        hNest.transfer(bob, 50 ether);

        assertEq(hype.balanceOf(alice), pendingBefore);
        assertEq(vault.pendingResidualHype(alice), 0);
        assertEq(vault.pendingResidualHype(bob), 0);
        assertEq(hNest.balanceOf(alice), 50 ether);
        assertEq(hNest.balanceOf(bob), 50 ether);
    }

    function test_WithdrawQueueAfterUnlock() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        vm.prank(alice);
        vault.requestWithdraw(100 ether);
        assertEq(hNest.balanceOf(alice), 0);
        assertEq(vault.totalNestLocked(), 0);

        uint256 tokenId = vault.getVeNFTId(0);

        // Harvest alone must NOT eager-dettach
        vm.prank(keeper);
        vault.harvest();
        assertTrue(vault.inHev(tokenId));
        assertEq(nest.balanceOf(alice), 10_000 ether - 100 ether);

        // 4d detachment gate
        vm.warp(block.timestamp + DETACH_LOCK + 1);
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;
        vm.prank(keeper);
        vault.dettachForLiquidity(ids);
        assertFalse(vault.inHev(tokenId));
        assertEq(vault.unlockEligibleAt(tokenId), block.timestamp + LOCK);

        // Default mock liveDettachReset=true: end = dettach+26w; vault waits unlockEligibleAt
        vm.warp(vault.unlockEligibleAt(tokenId) + 1);

        vm.prank(keeper);
        vault.harvest();

        assertEq(nest.balanceOf(alice), 10_000 ether); // refunded 100
        (,, uint256 pending) = vault.withdrawQueueStatus();
        assertEq(pending, 0);
    }

    function test_RecordCompoundDisabled() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        assertEq(vault.sharePrice(), 1e18);

        vm.prank(keeper);
        vm.expectRevert(NestVault.CompoundDisabled.selector);
        vault.recordCompound(10 ether);
        assertEq(vault.sharePrice(), 1e18);
        assertEq(vault.totalNestLocked(), 100 ether);
    }

    function test_UnbackedCompoundCannotInflateWithdrawLiability() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        // Unbacked compound must revert — cannot raise liability above vault assets
        vm.prank(keeper);
        vm.expectRevert(NestVault.CompoundDisabled.selector);
        vault.recordCompound(900 ether);

        vm.prank(alice);
        vault.requestWithdraw(100 ether);

        (,, uint256 pending) = vault.withdrawQueueStatus();
        assertEq(pending, 1);
        // Queue liability equals deposited principal, not inflated
        assertEq(vault.pendingWithdrawNest(), 100 ether);
        assertEq(vault.totalNestLocked(), 0);
    }

    function test_PauseBlocksDeposit() public {
        vault.pause();
        vm.prank(alice);
        vm.expectRevert();
        vault.deposit(1 ether);
    }

    function test_PauseBlocksRequestWithdraw() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        vault.pause();

        vm.prank(alice);
        vm.expectRevert();
        vault.requestWithdraw(50 ether);
    }

    function test_GuardianCanPause() public {
        vm.prank(guardian);
        vault.pause();
        assertTrue(vault.paused());

        vm.prank(alice);
        vm.expectRevert();
        vault.deposit(1 ether);
    }

    function test_KeeperCannotPause() public {
        vm.prank(keeper);
        vm.expectRevert(NestVault.NotGuardianOrOwner.selector);
        vault.pause();
        assertFalse(vault.paused());
    }

    function test_KeeperCannotUnpause() public {
        vault.pause();
        vm.prank(keeper);
        vm.expectRevert();
        vault.unpause();
        assertTrue(vault.paused());
    }

    function test_GuardianCannotUnpause() public {
        vault.pause();
        vm.prank(guardian);
        vm.expectRevert();
        vault.unpause();
        assertTrue(vault.paused());
    }

    function test_OnlyOwnerUnpauses() public {
        vm.prank(guardian);
        vault.pause();
        assertTrue(vault.paused());

        vault.unpause(); // owner (this contract) unpauses
        assertFalse(vault.paused());

        vm.prank(alice);
        vault.deposit(1 ether);
        assertEq(hNest.balanceOf(alice), 1 ether);
    }

    function test_SetGuardianAllowsZeroToDisable() public {
        vault.setGuardian(address(0));
        assertEq(vault.guardian(), address(0));

        vm.prank(guardian);
        vm.expectRevert(NestVault.NotGuardianOrOwner.selector);
        vault.pause();

        // owner can still pause
        vault.pause();
        assertTrue(vault.paused());
    }

    // ============ Idle buffer / withdraw windows ============

    function test_IdleDepositSkimFundsBuffer() public {
        vault.setIdleDepositBps(1_000); // 10%
        vm.prank(alice);
        vault.deposit(100 ether);

        assertEq(nest.balanceOf(address(vault)), 10 ether);
        assertEq(vault.availableIdleNest(), 10 ether);
        assertEq(vault.totalVeNFTs(), 1);
        assertEq(vault.nestPrincipal(vault.getVeNFTId(0)), 90 ether);
        assertEq(vault.totalNestLocked(), 100 ether);
    }

    function test_WithdrawFulfilledFromIdleSurplus() public {
        vault.setIdleDepositBps(1_000); // 10%
        vm.prank(alice);
        vault.deposit(100 ether);

        vm.prank(alice);
        vault.requestWithdraw(10 ether); // 10 NEST liability

        vm.prank(keeper);
        vault.harvest();

        assertEq(nest.balanceOf(alice), 10_000 ether - 100 ether + 10 ether);
        (,, uint256 pending) = vault.withdrawQueueStatus();
        assertEq(pending, 0);
        // NFT still attached — no eager dettach
        assertTrue(vault.inHev(vault.getVeNFTId(0)));
    }

    function test_IdleShortfallRevertsWhenMinBlocksHead() public {
        vault.setIdleDepositBps(1_000); // 10 idle on 100 deposit
        vm.prank(alice);
        vault.deposit(100 ether);

        // Reserve all current idle as floor
        vault.setMinIdleNest(10 ether);
        assertEq(vault.availableIdleNest(), 0);

        vm.prank(alice);
        vault.requestWithdraw(5 ether);

        // Raw balance (10) could pay 5, but minIdleNest blocks it
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(NestVault.IdleBufferShortfall.selector, uint256(0), uint256(5 ether))
        );
        vault.processWithdrawQueueOrRevert();

        (,, uint256 pending) = vault.withdrawQueueStatus();
        assertEq(pending, 1);
    }

    function test_SetMinIdleNestRevertsIfBalanceShort() public {
        vm.expectRevert(abi.encodeWithSelector(NestVault.IdleBufferShortfall.selector, uint256(0), uint256(1 ether)));
        vault.setMinIdleNest(1 ether);
    }

    function test_DettachTooEarlyReverts() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        vault.requestWithdraw(100 ether);

        uint256 tokenId = vault.getVeNFTId(0);
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;

        uint256 availableAt = vault.attachedAt(tokenId) + DETACH_LOCK;
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(NestVault.DettachTooEarly.selector, tokenId, availableAt));
        vault.dettachForLiquidity(ids);
    }

    function test_LiveDettachResetsLockTo26w() public {
        ve.setLiveDettachReset(true);

        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        vault.requestWithdraw(100 ether);

        uint256 tokenId = vault.getVeNFTId(0);
        vm.warp(block.timestamp + DETACH_LOCK + 1);

        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;
        uint256 dettachTime = block.timestamp;
        vm.prank(keeper);
        vault.dettachForLiquidity(ids);

        IVotingEscrow.TokenState memory st = ve.getNftState(tokenId);
        assertFalse(st.isAttached);
        assertEq(st.locked.end, dettachTime + LOCK);
        assertEq(vault.unlockEligibleAt(tokenId), dettachTime + LOCK);
        assertEq(uint256(int256(st.locked.amount)), 100 ether); // principal restored on chain
        assertEq(vault.nestPrincipal(tokenId), 100 ether); // vault tracking unchanged

        // Too early to unlock
        vm.prank(keeper);
        vault.harvest();
        assertEq(vault.totalVeNFTs(), 1);
        assertEq(nest.balanceOf(alice), 10_000 ether - 100 ether);

        vm.warp(dettachTime + LOCK + 1);
        vm.prank(keeper);
        vault.harvest();
        assertEq(nest.balanceOf(alice), 10_000 ether);
        assertEq(vault.totalVeNFTs(), 0);
    }

    function test_TopUpIdleThenFulfill() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        vault.requestWithdraw(50 ether);

        // No idle skim — queue waits
        vm.prank(keeper);
        vault.harvest();
        (,, uint256 pending) = vault.withdrawQueueStatus();
        assertEq(pending, 1);

        vm.prank(keeper);
        vault.topUpIdle(50 ether);

        vm.prank(keeper);
        vault.processWithdrawQueue();
        assertEq(nest.balanceOf(alice), 10_000 ether - 100 ether + 50 ether);
        (,, pending) = vault.withdrawQueueStatus();
        assertEq(pending, 0);
        // NFT still attached
        assertTrue(vault.inHev(vault.getVeNFTId(0)));
    }

    function test_RequestWithdrawDoesNotDettach() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        uint256 tokenId = vault.getVeNFTId(0);

        vm.prank(alice);
        vault.requestWithdraw(50 ether);

        assertTrue(vault.inHev(tokenId));
        assertTrue(ve.getNftState(tokenId).isAttached);
        assertEq(vault.unlockEligibleAt(tokenId), 0);
    }

    function test_GuardianCannotSetIdleParams() public {
        vm.prank(guardian);
        vm.expectRevert();
        vault.setIdleDepositBps(500);

        vm.prank(guardian);
        vm.expectRevert();
        vault.setMinIdleNest(1);

        // Owner can set idle params
        vault.setIdleDepositBps(500);
        assertEq(vault.idleDepositBps(), 500);

        vm.prank(alice);
        vault.deposit(100 ether);

        vault.setMinIdleNest(5 ether);
        assertEq(vault.minIdleNest(), 5 ether);
        assertEq(vault.availableIdleNest(), 0); // 5 idle, min 5
    }

    function test_IdleDepositBpsCap() public {
        vm.expectRevert(NestVault.IdleDepositBpsTooHigh.selector);
        vault.setIdleDepositBps(2_001);
    }

    // ============ HL-007 depositsEnabled ============

    function test_DepositsDisabledByDefaultUntilOwnerEnables() public {
        MockHevAdapter tmp2 = new MockHevAdapter(address(ve), address(hype), address(0));
        NestVault v2 = new NestVault(
            address(nest),
            address(ve),
            address(hype),
            address(tmp2),
            feeRecipient,
            keeper,
            guardian,
            0,
            address(0)
        );
        tmp2.setVault(address(v2));
        assertFalse(v2.depositsEnabled());

        nest.mint(alice, 1 ether);
        vm.prank(alice);
        nest.approve(address(v2), type(uint256).max);
        vm.prank(alice);
        vm.expectRevert(NestVault.DepositsDisabled.selector);
        v2.deposit(1 ether);

        v2.setDepositsEnabled(true);
        vm.prank(alice);
        v2.deposit(1 ether);
        assertEq(v2.hNest().balanceOf(alice), 1 ether);
    }

    // ============ HL-008 setHevAdapter(0) / dettach state machine ============

    function test_SetHevAdapterRejectsZero() public {
        vm.expectRevert(NestVault.ZeroAddress.selector);
        vault.setHevAdapter(address(0));
    }

    function test_DettachCannotClearAdapterToZeroAndStuckPathPrevented() public {
        MockHevAdapter a = new MockHevAdapter(address(ve), address(hype), address(0));
        NestVault v0 = new NestVault(
            address(nest),
            address(ve),
            address(hype),
            address(a),
            feeRecipient,
            keeper,
            guardian,
            0,
            address(0)
        );
        a.setVault(address(v0));
        v0.setDepositsEnabled(true);

        nest.mint(alice, 100 ether);
        vm.prank(alice);
        nest.approve(address(v0), type(uint256).max);
        vm.prank(alice);
        v0.deposit(100 ether);
        vm.prank(alice);
        v0.requestWithdraw(100 ether);

        uint256 tokenId = v0.getVeNFTId(0);
        assertTrue(v0.inHev(tokenId));

        // Cannot clear adapter to zero (HL-008)
        vm.expectRevert(NestVault.ZeroAddress.selector);
        v0.setHevAdapter(address(0));

        vm.warp(block.timestamp + DETACH_LOCK + 1);
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;
        vm.prank(keeper);
        v0.dettachForLiquidity(ids);

        // State cleared only after successful withdrawVeNFT — chain detached
        assertFalse(v0.inHev(tokenId));
        assertFalse(ve.getNftState(tokenId).isAttached);
        assertGt(v0.unlockEligibleAt(tokenId), 0);
    }

    function test_DettachRequiresAdapterAndSucceedsOnlyAfterWithdraw() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        vault.requestWithdraw(100 ether);

        uint256 tokenId = vault.getVeNFTId(0);
        assertTrue(vault.inHev(tokenId));
        assertTrue(ve.getNftState(tokenId).isAttached);

        vm.warp(block.timestamp + DETACH_LOCK + 1);
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;

        vm.prank(keeper);
        vault.dettachForLiquidity(ids);

        assertFalse(vault.inHev(tokenId));
        assertFalse(ve.getNftState(tokenId).isAttached);
        assertGt(vault.unlockEligibleAt(tokenId), 0);
        vm.warp(vault.unlockEligibleAt(tokenId) + 1);
        vm.prank(keeper);
        vault.processWithdrawQueue();
        assertEq(nest.balanceOf(alice), 10_000 ether);
    }

    // ============ HL-003 dettach principal cap ============

    function test_DettachCapsPrincipalToQueueGap() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(bob);
        vault.deposit(100 ether);

        vm.prank(alice);
        vault.requestWithdraw(50 ether);

        uint256 id0 = vault.getVeNFTId(0);
        uint256 id1 = vault.getVeNFTId(1);
        vm.warp(block.timestamp + DETACH_LOCK + 1);

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;

        vm.prank(keeper);
        vault.dettachForLiquidity(ids);

        uint256 dettached;
        if (!vault.inHev(id0)) dettached += 1;
        if (!vault.inHev(id1)) dettached += 1;
        assertEq(dettached, 1);
        assertTrue(vault.inHev(id0) != vault.inHev(id1));
    }

    function test_DettachBufferAllowsExtraPrincipal() public {
        vault.setDettachBufferBps(5_000); // 50% buffer: gap 40 → cap 60; both 40-NEST NFTs may dettach

        vm.prank(alice);
        vault.deposit(40 ether);
        vm.prank(bob);
        vault.deposit(40 ether);

        vm.prank(alice);
        vault.requestWithdraw(40 ether);

        uint256 id0 = vault.getVeNFTId(0);
        uint256 id1 = vault.getVeNFTId(1);
        vm.warp(block.timestamp + DETACH_LOCK + 1);

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        vm.prank(keeper);
        vault.dettachForLiquidity(ids);

        assertFalse(vault.inHev(id0));
        assertFalse(vault.inHev(id1));
    }

    function test_DettachSkipsWhenIdleCoversQueue() public {
        vault.setIdleDepositBps(1_000);
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        vault.requestWithdraw(10 ether);

        uint256 tokenId = vault.getVeNFTId(0);
        vm.warp(block.timestamp + DETACH_LOCK + 1);
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;
        vm.prank(keeper);
        vault.dettachForLiquidity(ids);
        assertTrue(vault.inHev(tokenId));
    }

    function test_MockLiveDettachResetOptOut() public {
        ve.setLiveDettachReset(false);
        uint256 before = block.timestamp;
        vm.prank(alice);
        vault.deposit(100 ether);
        uint256 tokenId = vault.getVeNFTId(0);
        uint256 depositEnd = before + LOCK;

        vm.prank(alice);
        vault.requestWithdraw(100 ether);
        vm.warp(block.timestamp + DETACH_LOCK + 1);
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;
        vm.prank(keeper);
        vault.dettachForLiquidity(ids);

        assertEq(ve.getNftState(tokenId).locked.end, depositEnd);
    }

    function test_DettachBufferBpsCap() public {
        vm.expectRevert(NestVault.DettachBufferBpsTooHigh.selector);
        vault.setDettachBufferBps(5_001);
    }
}
