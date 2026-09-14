// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {NestVaultC1} from "../src/NestVaultC1.sol";
import {HNest} from "../src/HNest.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockVotingEscrow} from "./mocks/MockVotingEscrow.sol";
import {MockHevAdapter} from "./mocks/MockHevAdapter.sol";
import {MockMerkleAirdrop} from "./mocks/MockMerkleAirdrop.sol";
import {HyperEVMAddresses} from "../src/config/HyperEVMAddresses.sol";

contract NestVaultC1Test is Test {
    // Re-declared for vm.expectEmit (must match src/NestVaultC1.sol).
    event MerkleClaimed(address indexed caller, uint256 received);
    event HarvestExecuted(uint256 hypeClaimed, uint256 feesTaken);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event YieldWrittenDown(uint256 removedNest);

    bytes32 constant INBOUND_SETTLED_TOPIC = keccak256("InboundHypeSettled(uint256,uint256,uint256)");

    MockERC20 nest;
    MockERC20 hype;
    MockVotingEscrow ve;
    MockHevAdapter adapter;
    MockMerkleAirdrop merkle;
    NestVaultC1 vault;
    HNest hNest;

    address gate = makeAddr("gate");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
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

    /// @dev Live WHypeAirdrop leaf: double-hashed (addr, amount), amount cumulative.
    function _leaf(address who, uint256 amount) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(who, amount))));
    }

    /// @dev Single-leaf week: root == leaf, so the valid proof is empty.
    function _setVaultWeek(uint256 cumulative) internal {
        merkle.setRoot(_leaf(address(vault), cumulative));
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _deploySecondVault(uint256 cap) internal returns (NestVaultC1 v, MockHevAdapter a) {
        a = new MockHevAdapter(address(ve), address(hype), address(0));
        v = new NestVaultC1(
            address(nest), address(ve), address(hype), address(a), feeRecipient, keeper, guardian, cap, address(0), address(merkle)
        );
        a.setVault(address(v));
        v.setDepositGate(gate);
        v.setDepositsEnabled(true);
        vm.prank(gate);
        nest.approve(address(v), type(uint256).max);
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
        _setVaultWeek(1 ether);
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
        _setVaultWeek(1 ether);
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
        _setVaultWeek(1 ether);
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
        _setVaultWeek(1 ether);
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

    function testRoundingDustCarriesToNextSettle() public {
        _deposit(3 ether);
        hype.mint(address(vault), 101);
        vault.settleInboundHype();
        assertEq(hype.balanceOf(feeRecipient), 1);
        assertEq(vault.pendingResidualHype(gate), 99);
        assertEq(hype.balanceOf(address(vault)), 100);

        vault.settleInboundHype();
        assertEq(vault.pendingResidualHype(gate), 99);

        hype.mint(address(vault), 2);
        vault.settleInboundHype();
        assertEq(vault.pendingResidualHype(gate), 102);
        vm.prank(gate);
        vault.claimResidualHype();
        assertEq(hype.balanceOf(gate), 102);
        assertEq(hype.balanceOf(address(vault)), 0);
    }

    function testRejectsForeignNft() public {
        StrayNft nft = new StrayNft();
        nft.mint(alice, 1);
        vm.prank(alice);
        vm.expectRevert(NestVaultC1.UnknownNft.selector);
        nft.safeTransferFrom(alice, address(vault), 1);
    }

    function testOwnerCanRescueStrayNftNotRegisteredVe() public {
        _deposit(1 ether);
        StrayNft nft = new StrayNft();
        nft.mint(address(vault), 7);
        vault.recoverERC721(address(nft), 7, alice);
        assertEq(nft.ownerOf(7), alice);

        uint256 veId = vault.getVeNFTId(0);
        vm.expectRevert(NestVaultC1.ProtectedVeNft.selector);
        vault.recoverERC721(address(ve), veId, alice);
    }

    /* ------------------------- R2 FIX-1 regression ------------------------- */

    /// @notice deposit() must pay the caller's accrued pending WHYPE before the post-mint
    ///         reward-debt overwrite, otherwise it is zeroed and permanently stranded.
    function testDepositClaimsPendingResidualHype() public {
        _deposit(100 ether);
        hype.mint(address(vault), 1 ether);
        vault.settleInboundHype();
        uint256 net = 1 ether - (1 ether / 100);
        assertEq(vault.pendingResidualHype(gate), net);

        // Gate deposits again WITHOUT claiming (edge path: gate migration / failed sync).
        _deposit(50 ether);

        assertEq(hype.balanceOf(gate), net);
        assertEq(vault.pendingResidualHype(gate), 0);
        assertEq(vault.hypeAccounted(), hype.balanceOf(address(vault)));
        assertEq(vault.hypeAccounted(), 0);
    }

    /* ------------------------- R2 FIX-2 regression ------------------------- */

    /// @notice Sub-distributable dust must settle nothing: no fee, no event, no state change.
    function testSubDistributableDustDefersFeeAndEvent() public {
        _deposit(100 ether); // supply 100e18 → net < 100 wei can never distribute
        hype.mint(address(vault), 100); // fee would be 1 wei, net 99 → deltaAcc == 0

        vm.recordLogs();
        vault.settleInboundHype();
        vault.settleInboundHype();
        vault.settleInboundHype();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            assertTrue(logs[i].topics[0] != INBOUND_SETTLED_TOPIC, "unexpected InboundHypeSettled");
        }
        assertEq(hype.balanceOf(feeRecipient), 0);
        assertEq(hype.balanceOf(address(vault)), 100);
        assertEq(vault.hypeAccounted(), 0);
    }

    /// @notice When dust accumulates past the threshold, exactly one fee is taken on the
    ///         cumulative inbound — deferred fees are not lost.
    function testDustAccumulatesThenSingleFeeOnCumulative() public {
        _deposit(100 ether);
        hype.mint(address(vault), 100);
        vault.settleInboundHype(); // deferred
        assertEq(hype.balanceOf(feeRecipient), 0);

        hype.mint(address(vault), 100); // cumulative inbound 200
        vm.recordLogs();
        vault.settleInboundHype();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 settleEvents;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == INBOUND_SETTLED_TOPIC) ++settleEvents;
        }
        assertEq(settleEvents, 1);
        assertEq(hype.balanceOf(feeRecipient), 2); // 1% of cumulative 200, taken exactly once
        assertEq(vault.pendingResidualHype(gate), 100); // net 198, dust 98 rolls forward
    }

    /* ------------------------- R2 FIX-3 truthful events ------------------------- */

    /// @notice MerkleClaimed must carry the actual received delta, not the cumulative amount.
    function testClaimMerkleEmitsReceivedDeltaCrossWeek() public {
        _deposit(100 ether);
        hype.mint(address(merkle), 3 ether);
        bytes32[] memory proof;

        _setVaultWeek(1 ether);
        vm.expectEmit();
        emit MerkleClaimed(stranger, 1 ether);
        vm.prank(stranger);
        vault.claimMerkle(proof, 1 ether);

        // Thursday root rotation: new root, higher cumulative → only the delta moves.
        _setVaultWeek(25 ether / 10);
        vm.expectEmit();
        emit MerkleClaimed(stranger, 15 ether / 10);
        vm.prank(stranger);
        vault.claimMerkle(proof, 25 ether / 10);

        assertEq(hype.balanceOf(feeRecipient), 25 ether / 1000); // 1% of cumulative 2.5
        assertEq(vault.pendingResidualHype(gate), 25 ether / 10 - 25 ether / 1000);
    }

    /// @notice harvest() must report the real settled gross/fee, not hardcoded zeros.
    function testHarvestEmitsRealValues() public {
        _deposit(100 ether);
        uint256 id = vault.getVeNFTId(0);
        hype.mint(alice, 2 ether);
        vm.startPrank(alice);
        hype.approve(address(adapter), 2 ether);
        adapter.seedReward(id, 2 ether);
        vm.stopPrank();

        vm.expectEmit();
        emit HarvestExecuted(2 ether, 2 ether / 100);
        vm.prank(keeper);
        vault.harvest();
        assertEq(hype.balanceOf(feeRecipient), 2 ether / 100);
    }

    function testSetFeeRecipientEmitsEvent() public {
        vm.expectEmit();
        emit FeeRecipientUpdated(feeRecipient, alice);
        vault.setFeeRecipient(alice);
        assertEq(vault.feeRecipient(), alice);
    }

    /* ------------------------- R2 FIX-4 pagination ------------------------- */

    /// @notice Paginated booking over [0,2)+[2,4) must equal a single full-range booking.
    ///         feeBps = 0 here so fee-share rounding cannot diverge between the two paths.
    function testPaginatedBookingEqualsSingleCall() public {
        vault.setFee(0);
        (NestVaultC1 v2, MockHevAdapter a2) = _deploySecondVault(0);
        v2.setFee(0);

        for (uint256 i; i < 4; ++i) {
            _deposit(25 ether);
            vm.prank(gate);
            v2.deposit(25 ether);
        }
        for (uint256 i; i < 4; ++i) {
            adapter.seedLockedShare(vault.getVeNFTId(i), (i + 1) * 1 ether);
            a2.seedLockedShare(v2.getVeNFTId(i), (i + 1) * 1 ether);
        }

        vm.prank(keeper);
        vault.bookVerifiedYield(0, 2);
        vm.prank(keeper);
        vault.bookVerifiedYield(2, 4);
        vm.prank(keeper);
        v2.bookVerifiedYield();

        assertEq(vault.totalNestLocked(), v2.totalNestLocked());
        assertEq(vault.totalNestLocked(), 110 ether);
        assertEq(vault.yieldBookedThisEpoch(), v2.yieldBookedThisEpoch());
        for (uint256 i; i < 4; ++i) {
            assertEq(vault.bookedLockedShare(vault.getVeNFTId(i)), v2.bookedLockedShare(v2.getVeNFTId(i)));
        }
    }

    function testPaginatedBookOutOfBoundsReverts() public {
        _deposit(1 ether);
        _deposit(1 ether);
        vm.startPrank(keeper);
        vm.expectRevert(abi.encodeWithSelector(NestVaultC1.InvalidBookRange.selector, 1, 3, 2));
        vault.bookVerifiedYield(1, 3);
        vm.expectRevert(abi.encodeWithSelector(NestVaultC1.InvalidBookRange.selector, 2, 1, 2));
        vault.bookVerifiedYield(2, 1);
        vm.expectRevert(abi.encodeWithSelector(NestVaultC1.InvalidBookRange.selector, 0, 0, 2));
        vault.bookVerifiedYield(0, 0);
        vm.stopPrank();
    }

    /// @notice The weekly MAX_YIELD_BOOK_BPS cap accumulates across paginated calls.
    function testWeeklyCapEnforcedAcrossPaginatedCalls() public {
        _deposit(50 ether);
        _deposit(50 ether);
        uint256 id0 = vault.getVeNFTId(0);
        uint256 id1 = vault.getVeNFTId(1);
        // cap = 10% of 100 ether = 10 ether for the week.
        adapter.seedLockedShare(id0, 6 ether);
        adapter.seedLockedShare(id1, 6 ether);
        vm.prank(keeper);
        vault.bookVerifiedYield(0, 1); // 6 ether booked
        // Second call: totalNestLocked is now 106 ether → remaining allowance 10.6 - 6 = 4.6 ether.
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(NestVaultC1.YieldBookTooLarge.selector, 6 ether, 46 ether / 10));
        vault.bookVerifiedYield(1, 2);
    }

    /* ------------------------- R2 FIX-6 extended coverage ------------------------- */

    /// 1. Multi-user HYPE fairness with interleaved settles/claims.
    function testMultiUserHypeFairness() public {
        _deposit(100 ether);
        vm.prank(gate);
        hNest.transfer(alice, 40 ether);
        vm.prank(gate);
        hNest.transfer(bob, 10 ether);
        // gate 50 / alice 40 / bob 10

        hype.mint(address(vault), 10 ether);
        vault.settleInboundHype();
        vm.prank(alice); // interleaved claim between settles
        vault.claimResidualHype();
        assertEq(hype.balanceOf(alice), 396 ether / 100);

        hype.mint(address(vault), 5 ether);
        vault.settleInboundHype();
        vm.prank(alice);
        vault.claimResidualHype();
        vm.prank(bob);
        vault.claimResidualHype();
        vm.prank(gate);
        vault.claimResidualHype();

        assertEq(hype.balanceOf(feeRecipient), 15 ether / 100);
        assertEq(hype.balanceOf(alice), 594 ether / 100); // 40% of net 14.85
        assertEq(hype.balanceOf(bob), 1485 ether / 1000); // 10%
        assertEq(hype.balanceOf(gate), 7425 ether / 1000); // 50%
        uint256 sumClaims = hype.balanceOf(alice) + hype.balanceOf(bob) + hype.balanceOf(gate);
        assertEq(sumClaims, vault.totalHypeDistributed());
        assertEq(sumClaims, 1485 ether / 100);
        assertGe(hype.balanceOf(address(vault)), vault.hypeAccounted());
    }

    /// 2. settle-then-claim and claim-then-settle give identical outcomes.
    function testSettleThenClaimEqualsClaimThenSettle() public {
        _deposit(100 ether);

        hype.mint(address(vault), 1 ether);
        vault.settleInboundHype();
        vm.prank(gate);
        vault.claimResidualHype();
        uint256 gateA = hype.balanceOf(gate);
        uint256 feeA = hype.balanceOf(feeRecipient);

        hype.mint(address(vault), 1 ether);
        vm.prank(gate);
        vault.claimResidualHype(); // settles internally first
        assertEq(hype.balanceOf(gate) - gateA, gateA);
        assertEq(hype.balanceOf(feeRecipient) - feeA, feeA);
    }

    /// 3. bookVerifiedYield write-down paths: down-only and mixed down+up.
    function testBookVerifiedYieldWriteDown() public {
        _deposit(50 ether);
        _deposit(50 ether);
        uint256 id0 = vault.getVeNFTId(0);
        uint256 id1 = vault.getVeNFTId(1);

        adapter.seedLockedShare(id0, 4 ether);
        adapter.seedLockedShare(id1, 2 ether);
        vm.prank(keeper);
        vault.bookVerifiedYield();
        assertEq(vault.totalNestLocked(), 106 ether);

        // Down-only: no yield booked, no revert, totalNestLocked shrinks.
        adapter.seedLockedShare(id0, 1 ether);
        vm.expectEmit();
        emit YieldWrittenDown(3 ether);
        vm.prank(keeper);
        vault.bookVerifiedYield();
        assertEq(vault.totalNestLocked(), 103 ether);

        // Mixed: id0 up 3, id1 down 1 → net +2 (down applied before the cap check).
        adapter.seedLockedShare(id0, 4 ether);
        adapter.seedLockedShare(id1, 1 ether);
        vm.expectEmit();
        emit YieldWrittenDown(1 ether);
        vm.prank(keeper);
        vault.bookVerifiedYield();
        assertEq(vault.totalNestLocked(), 105 ether);
        assertEq(vault.bookedLockedShare(id0), 4 ether);
        assertEq(vault.bookedLockedShare(id1), 1 ether);
    }

    /// 4. Weekly cap boundary: y == cap succeeds, cap+1 reverts, rollover resets.
    function testWeeklyCapBoundary() public {
        _deposit(100 ether);
        uint256 id = vault.getVeNFTId(0);

        // y == cap succeeds (cap = 10% of 100 ether).
        adapter.seedLockedShare(id, 10 ether);
        vm.prank(keeper);
        vault.bookVerifiedYield();
        assertEq(vault.yieldBookedThisEpoch(), 10 ether);

        // cap + 1 wei reverts on a fresh week state (fresh vault for a clean epoch).
        (NestVaultC1 v2, MockHevAdapter a2) = _deploySecondVault(0);
        vm.prank(gate);
        v2.deposit(100 ether);
        a2.seedLockedShare(v2.getVeNFTId(0), 10 ether + 1);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(NestVaultC1.YieldBookTooLarge.selector, 10 ether + 1, 10 ether));
        v2.bookVerifiedYield();

        // Week rollover resets the allowance; new cap is 10% of 110 ether.
        vm.warp(((block.timestamp / 7 days) + 1) * 7 days + 1);
        adapter.seedLockedShare(id, 21 ether);
        vm.prank(keeper);
        vault.bookVerifiedYield(); // y = 11 ether == new cap
        assertEq(vault.yieldBookedThisEpoch(), 11 ether);
    }

    /// 5. Access-control sweep.
    function testAccessControlSweep() public {
        vm.startPrank(stranger);
        bytes memory ownableErr = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger);
        vm.expectRevert(ownableErr);
        vault.setDepositGate(alice);
        vm.expectRevert(ownableErr);
        vault.setDepositsEnabled(false);
        vm.expectRevert(ownableErr);
        vault.setKeeper(alice);
        vm.expectRevert(ownableErr);
        vault.setGuardian(alice);
        vm.expectRevert(ownableErr);
        vault.setFee(1);
        vm.expectRevert(ownableErr);
        vault.setFeeRecipient(alice);
        vm.expectRevert(ownableErr);
        vault.setDepositCap(1);
        vm.expectRevert(ownableErr);
        vault.setHevAdapter(alice);
        vm.expectRevert(ownableErr);
        vault.setMerkleAirdrop(alice);
        vm.expectRevert(NestVaultC1.NotGuardianOrOwner.selector);
        vault.pause();
        vm.expectRevert(ownableErr);
        vault.unpause();
        vm.expectRevert(ownableErr);
        vault.recoverERC721(address(nest), 1, alice);
        vm.expectRevert(NestVaultC1.NotKeeper.selector);
        vault.bookVerifiedYield();
        vm.expectRevert(NestVaultC1.NotKeeper.selector);
        vault.bookVerifiedYield(0, 1);
        vm.expectRevert(NestVaultC1.NotKeeper.selector);
        vault.harvest();
        vm.stopPrank();

        // DepositsDisabled
        vault.setDepositsEnabled(false);
        vm.prank(gate);
        vm.expectRevert(NestVaultC1.DepositsDisabled.selector);
        vault.deposit(1 ether);
        vault.setDepositsEnabled(true);

        // DepositGateFrozen on second setDepositGate
        vm.expectRevert(NestVaultC1.DepositGateFrozen.selector);
        vault.setDepositGate(alice);

        // Pause blocks deposits; guardian pauses but cannot unpause.
        vm.prank(guardian);
        vault.pause();
        vm.prank(gate);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.deposit(1 ether);
        vm.prank(guardian);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, guardian));
        vault.unpause();
        vault.unpause();
        _deposit(1 ether);
    }

    /// 6. depositCap boundary: exact cap succeeds, cap+1 reverts, cap=0 unlimited.
    function testDepositCapBoundary() public {
        vault.setDepositCap(100 ether);
        _deposit(100 ether); // exact cap
        vm.prank(gate);
        vm.expectRevert(NestVaultC1.DepositCapExceeded.selector);
        vault.deposit(1);

        (NestVaultC1 v2,) = _deploySecondVault(0); // cap 0 = unlimited
        vm.prank(gate);
        v2.deposit(5_000 ether);
        assertEq(v2.totalNestLocked(), 5_000 ether);
    }

    /// 6b. Cap is measured against totalNestLocked INCLUDING booked yield.
    function testDepositCapIncludesBookedYield() public {
        _deposit(100 ether);
        uint256 id = vault.getVeNFTId(0);
        adapter.seedLockedShare(id, 10 ether);
        vm.prank(keeper);
        vault.bookVerifiedYield(); // totalNestLocked = 110 ether
        vault.setDepositCap(110 ether);
        vm.prank(gate);
        vm.expectRevert(NestVaultC1.DepositCapExceeded.selector);
        vault.deposit(1);
    }

    /// 7. setFee boundary + zero-fee settle path.
    function testSetFeeBoundaryAndZeroFeeSettle() public {
        vault.setFee(500);
        assertEq(vault.feeBps(), 500);
        vm.expectRevert(NestVaultC1.FeeTooHigh.selector);
        vault.setFee(501);

        vault.setFee(0);
        _deposit(100 ether);
        hype.mint(address(vault), 1 ether);
        vault.settleInboundHype();
        assertEq(hype.balanceOf(feeRecipient), 0);
        assertEq(vault.pendingResidualHype(gate), 1 ether);
    }

    /// 8a. claimMerkle reverts on an invalid proof (real merkle verification).
    function testClaimMerkleInvalidProofReverts() public {
        _deposit(1 ether);
        hype.mint(address(merkle), 3 ether);
        _setVaultWeek(1 ether);
        bytes32[] memory bogus = new bytes32[](1);
        bogus[0] = bytes32(uint256(1));
        vm.expectRevert(MockMerkleAirdrop.InvalidProof.selector);
        vault.claimMerkle(bogus, 1 ether);
        // Wrong cumulative amount → different leaf → invalid.
        bytes32[] memory proof;
        vm.expectRevert(MockMerkleAirdrop.InvalidProof.selector);
        vault.claimMerkle(proof, 2 ether);
    }

    /// 8b. claimMerkle verifies a real multi-leaf proof.
    function testClaimMerkleTwoLeafTree() public {
        _deposit(100 ether);
        hype.mint(address(merkle), 6 ether);
        bytes32 leafVault = _leaf(address(vault), 1 ether);
        bytes32 leafOther = _leaf(alice, 5 ether);
        merkle.setRoot(_hashPair(leafVault, leafOther));

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leafOther;
        vault.claimMerkle(proof, 1 ether);
        assertEq(hype.balanceOf(feeRecipient), 1 ether / 100);

        // Vault's amount-5 leaf is not in the tree.
        bytes32[] memory bad = new bytes32[](1);
        bad[0] = leafVault;
        vm.expectRevert(MockMerkleAirdrop.InvalidProof.selector);
        vault.claimMerkle(bad, 5 ether);
    }

    /// 8c. MerkleNotSet when no airdrop contract is configured.
    function testClaimMerkleNotSetReverts() public {
        MockHevAdapter tmp = new MockHevAdapter(address(ve), address(hype), address(0));
        NestVaultC1 v2 = new NestVaultC1(
            address(nest), address(ve), address(hype), address(tmp), feeRecipient, keeper, guardian, 0, address(0), address(0)
        );
        bytes32[] memory proof;
        vm.expectRevert(NestVaultC1.MerkleNotSet.selector);
        v2.claimMerkle(proof, 1 ether);
    }

    /// 8d. Double-claim of the same cumulative amount reverts AlreadyClaimed (live semantics).
    function testClaimMerkleDoubleClaimReverts() public {
        _deposit(1 ether);
        hype.mint(address(merkle), 2 ether);
        _setVaultWeek(1 ether);
        bytes32[] memory proof;
        vault.claimMerkle(proof, 1 ether);
        vm.expectRevert(MockMerkleAirdrop.AlreadyClaimed.selector);
        vault.claimMerkle(proof, 1 ether);
    }

    /// 9. recoverERC721 negatives.
    function testRecoverERC721Negatives() public {
        _deposit(1 ether);
        StrayNft nft = new StrayNft();
        nft.mint(address(vault), 7);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vault.recoverERC721(address(nft), 7, alice);

        vm.expectRevert(NestVaultC1.ZeroAddress.selector);
        vault.recoverERC721(address(nft), 7, address(0));

        uint256 veId = vault.getVeNFTId(0);
        vm.expectRevert(NestVaultC1.ProtectedVeNft.selector);
        vault.recoverERC721(address(ve), veId, alice);
    }

    /// 10. First-deposit capture: pre-launch WHYPE donation settles to the sole holder (gate),
    ///     fee to feeRecipient.
    function testFirstDepositCapture() public {
        hype.mint(address(vault), 1 ether); // pre-launch donation
        _deposit(100 ether);
        uint256 fee = 1 ether / 100;
        assertEq(hype.balanceOf(feeRecipient), fee);
        assertEq(vault.pendingResidualHype(gate), 1 ether - fee);
        vm.prank(gate);
        vault.claimResidualHype();
        assertEq(hype.balanceOf(gate), 1 ether - fee);
        assertEq(hype.balanceOf(address(vault)), 0);
    }

    /// Time-weight: holder who sat longer gets more of the Thursday pot than a late buyer.
    function testHypeTimeWeightLongerHolderGetsMore() public {
        _deposit(100 ether);
        vm.prank(gate);
        hNest.transfer(alice, 100 ether);
        skip(7 days);
        vm.prank(alice);
        hNest.transfer(bob, 50 ether);
        assertEq(hNest.balanceOf(alice), 50 ether);
        assertEq(hNest.balanceOf(bob), 50 ether);
        skip(7 days);
        hype.mint(address(vault), 100 ether);
        vault.settleInboundHype();
        uint256 fee = 1 ether;
        uint256 net = 99 ether;
        vm.prank(alice);
        vault.claimResidualHype();
        vm.prank(bob);
        vault.claimResidualHype();
        uint256 a = hype.balanceOf(alice);
        uint256 b = hype.balanceOf(bob);
        assertEq(hype.balanceOf(feeRecipient), fee);
        assertGt(a, b);
        assertApproxEqRel(a, (net * 3) / 4, 0.02e18);
        assertApproxEqRel(b, net / 4, 0.02e18);
        assertEq(a + b, net);
    }

    /// P1-01: dust settles intra-week must not open extra time-weight epochs.
    function testDustSettleDoesNotOpenWeeklyEpoch() public {
        _deposit(100 ether);
        skip(1 days);
        hype.mint(address(vault), 1 ether);
        vault.settleInboundHype();
        assertEq(vault.hypeEpochId(), 0);
        skip(1 days);
        hype.mint(address(vault), 1);
        vault.settleInboundHype();
        assertEq(vault.hypeEpochId(), 0);
        skip(5 days);
        hype.mint(address(vault), 1 ether);
        vault.settleInboundHype();
        assertEq(vault.hypeEpochId(), 1);
        vm.prank(gate);
        hNest.transfer(alice, 50 ether);
        assertEq(hNest.balanceOf(alice), 50 ether);
    }
}

contract StrayNft is ERC721 {
    constructor() ERC721("Stray", "STRAY") {}

    function mint(address to, uint256 id) external {
        _mint(to, id);
    }
}
