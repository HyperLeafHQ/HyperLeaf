// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LeafJitoRate} from "src/lz/LeafJitoRate.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LeafJitoPolicy} from "src/lz/LeafJitoPolicy.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

contract LeafJitoRateTest is Test {
    function testRateMatchesPoolRatio() public pure {
        uint64 lamports = 10_254_350_600_000_000;
        uint64 supply = 7_889_287_950_000_000;
        uint256 r = LeafJitoRate.rate(lamports, supply);
        assertGt(r, 1.29e18);
        assertLt(r, 1.31e18);
    }

    function testRetainFeeOnePercentOfSurplus() public pure {
        uint256 accounted = 100e9; // 100 JitoSOL
        uint256 r0 = 1e18;
        uint256 r1 = 1.1e18;
        (uint256 fee, uint256 next, uint256 nr) = LeafJitoRate.bookRetainFee(accounted, r0, r1);
        // surplus = 100e9 * 0.1e18 / 1.1e18 = 9_090_909_090
        // fee 1% = 90_909_090
        assertEq(fee, 90_909_090);
        assertEq(next, accounted - fee);
        assertEq(nr, r1);
    }

    function testSlashDropsWatermarkNoFee() public pure {
        (uint256 fee, uint256 next, uint256 nr) = LeafJitoRate.bookRetainFee(100e9, 1.1e18, 1.05e18);
        assertEq(fee, 0);
        assertEq(next, 100e9);
        assertEq(nr, 1.05e18);
    }

    function testDonationDoesNotCreateFee() public pure {
        // lastAccounted unchanged if we never book extra atoms
        (uint256 fee,,) = LeafJitoRate.bookRetainFee(100e9, 1e18, 1e18);
        assertEq(fee, 0);
    }

    function testShareRoundTripFirstDeposit() public pure {
        uint256 atoms = 5e9;
        uint256 shares = LeafJitoRate.sharesForAtoms(atoms, 0, 0);
        assertEq(shares, 5e18);
        uint256 back = LeafJitoRate.atomsFromShares(shares, atoms, shares);
        assertEq(back, atoms);
    }

    function testRedeemAfterSkimIsProRataRemaining() public pure {
        uint256 atoms = 100e9;
        uint256 shares = LeafJitoRate.sharesFromAtoms(atoms);
        (uint256 fee, uint256 remaining,) = LeafJitoRate.bookRetainFee(atoms, 1e18, 1.1e18);
        uint256 out = LeafJitoRate.atomsFromShares(shares, remaining, shares);
        assertEq(out, remaining);
        assertLt(out, atoms);
        assertEq(atoms - out, fee);
    }

    function testListingTagMatchesKeccak() public pure {
        assertEq(LeafJitoPolicy.LISTING_TAG, keccak256("hjitosol"));
        assertTrue(LeafJitoPolicy.isForbiddenProgram(LeafJitoPolicy.VAULT_PROGRAM));
        assertTrue(LeafJitoPolicy.isForbiddenProgram(LeafJitoPolicy.RESTAKING_PROGRAM));
        assertTrue(LeafJitoPolicy.isForbiddenProgram(LeafJitoPolicy.STAKE_POOL_PROGRAM));
        assertFalse(LeafJitoPolicy.isForbiddenProgram(bytes32(uint256(1))));
    }

    function testHarvestOtherRejectsJitoMint() public {
        vm.expectRevert(LeafJitoPolicy.CannotHarvestInner.selector);
        this._harvestOther(LeafJitoPolicy.JITO_MINT);
        LeafJitoPolicy.requireHarvestOther(bytes32(uint256(2)));
    }

    function _harvestOther(bytes32 mint) external pure {
        LeafJitoPolicy.requireHarvestOther(mint);
    }

    function testPayloadIsAbiEncodeTagToAmount() public {
        AssetCatalog.Listing memory a = AssetCatalog.get("hjitosol");
        assertEq(a.sourceEidMain, A.EID_SOLANA);
        assertEq(a.innerMainnet, address(0));
        assertFalse(a.productionEvm);
        assertEq(MainnetBatches.batchOf("hjitosol"), 5);
        bytes32 tag = LeafJitoPolicy.LISTING_TAG;
        assertEq(tag, keccak256("hjitosol"));
        bytes32 to = bytes32(uint256(uint160(address(0xBEEF))));
        uint256 amount = 1e18;
        bytes memory payload = abi.encode(tag, to, amount);
        (bytes32 t, bytes32 u, uint256 n) = abi.decode(payload, (bytes32, bytes32, uint256));
        assertEq(t, tag);
        assertEq(u, to);
        assertEq(n, amount);
        assertEq(payload.length, 96);
    }

    function testSolanaConfirmationsAre32() public pure {
        assertEq(A.confirmationsForEid(A.EID_SOLANA), 32);
        assertEq(A.confirmationsForEid(A.EID_HYPEREVM), 5);
    }

    function testJupsolNotBatchFive() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hjupsol");
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }
}
