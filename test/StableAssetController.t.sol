// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StableAssetController} from "src/StableAssetController.sol";
import {IStableAssetAdapter} from "src/interfaces/IStableAssetAdapter.sol";
import {MockStableAssetAdapter} from "test/mocks/MockStableAssetAdapter.sol";

contract StableAssetControllerTest is Test {
    bytes32 internal constant ID = keccak256("PYUSD");
    address internal constant LEAF = address(0x1111);

    StableAssetController internal controller;
    MockStableAssetAdapter internal adapter;

    function setUp() external {
        controller = new StableAssetController(address(this));
        adapter = new MockStableAssetAdapter();
        controller.registerListing(ID, LEAF, address(adapter), address(0));
        controller.setRiskConfig(
            ID,
            StableAssetController.RiskConfig({
                maxPegDeviationBps: 50,
                maxExitDiscountBps: 200,
                minExitCoverageBps: 9_000,
                maxEvidenceAge: 1 hours,
                maxPrimaryRedeemSlippageBps: 100,
                requirePrimaryRedeem: true
            })
        );
    }

    function _healthy() internal {
        adapter.setPeg(
            ID,
            IStableAssetAdapter.PegState({
                marketPrice: 1e18,
                referencePrice: 1e18,
                primaryRedeemPrice: 1e18,
                updatedAt: block.timestamp,
                deviationBps: 0
            })
        );
        adapter.setExit(
            ID,
            IStableAssetAdapter.ExitState({
                totalClaim: 1_000_000e18,
                immediatelyRedeemable: 950_000e18,
                bufferedLiquidity: 0,
                queuedAmount: 0,
                updatedAt: block.timestamp
            })
        );
    }

    function testHealthyListingIsMarketEnabled() external {
        _healthy();
        StableAssetController.Assessment memory a = controller.assess(ID);
        assertTrue(a.evidenceFresh);
        assertEq(uint8(a.pegStatus), uint8(StableAssetController.PegStatus.Normal));
        assertEq(uint8(a.exitMode), uint8(StableAssetController.ExitMode.PrimaryRedeem));
        assertTrue(a.primaryExitAllowed);
        assertTrue(a.marketEnabled);
        assertTrue(controller.canMint(ID));
    }

    function testStaleEvidenceFreezesMarketAndMint() external {
        _healthy();
        vm.warp(block.timestamp + 2 hours);
        StableAssetController.Assessment memory a = controller.assess(ID);
        assertFalse(a.evidenceFresh);
        assertEq(uint8(a.pegStatus), uint8(StableAssetController.PegStatus.Broken));
        assertEq(uint8(a.exitMode), uint8(StableAssetController.ExitMode.Frozen));
        assertFalse(a.marketEnabled);
        assertFalse(controller.canMint(ID));
    }

    function testLowExitCoverageDisablesPrimaryOnlyPolicy() external {
        _healthy();
        adapter.setExit(
            ID,
            IStableAssetAdapter.ExitState({
                totalClaim: 1_000_000e18,
                immediatelyRedeemable: 500_000e18,
                bufferedLiquidity: 0,
                queuedAmount: 0,
                updatedAt: block.timestamp
            })
        );
        StableAssetController.Assessment memory a = controller.assess(ID);
        assertEq(a.exitCoverageBps, 5_000);
        assertTrue(a.primaryExitAllowed);
        assertFalse(a.marketEnabled);
        assertEq(uint8(a.exitMode), uint8(StableAssetController.ExitMode.QueueRedeem));
    }

    function testPegDeviationClassifiesAsDegraded() external {
        _healthy();
        adapter.setPeg(
            ID,
            IStableAssetAdapter.PegState({
                marketPrice: 0.99e18,
                referencePrice: 1e18,
                primaryRedeemPrice: 0.999e18,
                updatedAt: block.timestamp,
                deviationBps: 100
            })
        );
        StableAssetController.Assessment memory a = controller.assess(ID);
        assertEq(uint8(a.pegStatus), uint8(StableAssetController.PegStatus.Degraded));
        assertFalse(a.primaryExitAllowed);
        assertFalse(a.marketEnabled);
        assertFalse(controller.canMint(ID));
    }

    function testPausedDisablesMint() external {
        _healthy();
        controller.pause();
        assertFalse(controller.canMint(ID));
        controller.unpause();
        assertTrue(controller.canMint(ID));
    }
}
