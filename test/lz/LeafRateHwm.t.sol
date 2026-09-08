// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockLbtcRouter} from "test/mocks/MockLbtcRouter.sol";

contract MockEndpointRateHwm is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30101;
    }

    function send(MessagingParams calldata p, address) external payable returns (MessagingReceipt memory r) {
        r.guid = keccak256(abi.encode(p, block.number));
        r.nonce = 1;
        r.fee = MessagingFee(msg.value, 0);
    }

    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee(0.01 ether, 0);
    }

    function setDelegate(address) external {}
    function setConfig(address, address, SetConfigParam[] calldata) external {}
    function getConfig(address, address, uint32, uint32) external pure returns (bytes memory) {
        return "";
    }
    function skip(address, uint32, bytes32, uint64) external {}
}

contract LeafRateHwmTest is Test {
    MockEndpointRateHwm endpoint;
    MockERC20 inner;
    MockLbtcRouter router;
    LeafOFTAdapter adapter;

    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address converter = address(0xC0DE);
    address alice = address(0xCAFE);
    address bob = address(0xB0B2);

    function setUp() public {
        endpoint = new MockEndpointRateHwm();
        inner = new MockERC20("RATE", "RATE");
        router = new MockLbtcRouter();
        router.setRate(address(inner), 1e18);

        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(endpoint), owner, guardian, feeTo, 1_000_000 ether);
        adapter.setConverter(converter);
        adapter.setRewardsTarget(address(router));
        adapter.setShareScale(1);
        adapter.setMaxRateJumpBps(0);
        adapter.setRateKind(LeafYieldFee.RateKind.RouterGetRate);
        adapter.setRetainRateYield(true);
        adapter.setConvertYieldToHype(true);
        adapter.setInnerSupplyCeiling(1_000_000_000 ether);
        adapter.setListingTag(keccak256("RATE-HWM"));
        adapter.setLimits(1_000_000 ether, 1_000_000 ether);
        adapter.setPeer(30367, address(1));
        adapter.openBridge();
        vm.stopPrank();

        inner.mint(alice, 1_000 ether);
        inner.mint(bob, 1_000 ether);
        vm.prank(alice);
        inner.approve(address(adapter), type(uint256).max);
        vm.prank(bob);
        inner.approve(address(adapter), type(uint256).max);
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    function _deposit(address user, uint256 amount) internal {
        vm.prank(user);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), amount, user);
    }

    function test_SlashRecoveryDoesNotManufactureYield() public {
        _deposit(alice, 100 ether);

        router.setRate(address(inner), 0.90e18);
        adapter.pokeRate();
        assertEq(adapter.rateCostBasis(), 100 ether);
        assertEq(adapter.pendingRateYield(address(inner)), 0);

        router.setRate(address(inner), 1e18);
        adapter.pokeRate();
        assertEq(adapter.rateCostBasis(), 100 ether);
        assertEq(adapter.accruedRateYield(), 0);
        assertEq(adapter.pendingRateYield(address(inner)), 0);
        assertEq(inner.balanceOf(converter), 0);
    }

    function test_RecoveryOnlyChargesNetGrowthAboveOriginalCostBasis() public {
        _deposit(alice, 100 ether);

        router.setRate(address(inner), 0.90e18);
        adapter.pokeRate();

        router.setRate(address(inner), 1.05e18);
        adapter.pokeRate();

        uint256 expectedFeeTokens = (5 ether * 1e18) / (1.05e18 * 100);
        assertEq(inner.balanceOf(converter), expectedFeeTokens);
        assertEq(adapter.accruedRateYield(), 0);
        assertEq(adapter.rateCostBasis(), 105 ether - (expectedFeeTokens * 1.05e18) / 1e18);
    }

    function test_DepositDuringDrawdownDoesNotInheritHistoricalLoss() public {
        _deposit(alice, 100 ether);

        router.setRate(address(inner), 0.90e18);
        adapter.pokeRate();

        _deposit(bob, 100 ether);
        assertEq(adapter.rateCostBasis(), 190 ether);

        router.setRate(address(inner), 1e18);
        adapter.pokeRate();

        uint256 expectedFee = 0.1 ether;
        assertEq(inner.balanceOf(converter), expectedFee);
        assertEq(adapter.rateCostBasis(), 200 ether - expectedFee);
    }

    function test_PartialRedemptionPreservesCostBasisHwm() public {
        _deposit(alice, 100 ether);

        router.setRate(address(inner), 0.90e18);
        adapter.pokeRate();

        vm.prank(guardian);
        adapter.setHealth(LeafOApp.Health.Insolvent);

        uint256 halfShares = adapter.totalLocked() / 2;
        vm.prank(owner);
        adapter.abortCredit(alice, halfShares);

        assertEq(adapter.totalLocked(), halfShares);
        assertEq(adapter.rateCostBasis(), 50 ether);

        router.setRate(address(inner), 1e18);
        adapter.pokeRate();
        assertEq(adapter.rateCostBasis(), 50 ether);
        assertEq(adapter.accruedRateYield(), 0);
        assertEq(adapter.pendingRateYield(address(inner)), 0);

        router.setRate(address(inner), 1.10e18);
        adapter.pokeRate();
        uint256 expectedFeeTokens = (5 ether * 1e18) / (1.10e18 * 100);
        assertEq(inner.balanceOf(converter), expectedFeeTokens);
    }

    function test_DownThenFurtherDownStillNoFee() public {
        _deposit(alice, 100 ether);

        router.setRate(address(inner), 0.90e18);
        adapter.pokeRate();
        router.setRate(address(inner), 0.80e18);
        adapter.pokeRate();

        assertEq(adapter.rateCostBasis(), 100 ether);
        assertEq(adapter.accruedRateYield(), 0);
        assertEq(adapter.pendingRateYield(address(inner)), 0);
        assertEq(inner.balanceOf(converter), 0);
    }
}
