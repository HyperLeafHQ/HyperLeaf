// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LPPositionManager} from "../src/LPPositionManager.sol";
import {ILPPositionAdapter} from "../src/interfaces/ILPPositionAdapter.sol";
import {MockLPPositionAdapter} from "./mocks/MockLPPositionAdapter.sol";

contract LPPositionManagerTest is Test {
    LPPositionManager manager;
    MockLPPositionAdapter adapter;

    address owner = makeAddr("owner");
    address keeper = makeAddr("keeper");
    address attacker = makeAddr("attacker");
    bytes32 positionId = keccak256("hyperleaf:lp:test");

    function setUp() public {
        manager = new LPPositionManager(owner);
        adapter = new MockLPPositionAdapter(address(manager));

        vm.startPrank(owner);
        manager.registerPosition(
            positionId,
            address(adapter),
            keeper,
            100,
            100,
            1_000,
            2_000
        );
        vm.stopPrank();

        adapter.setState(
            ILPPositionAdapter.PositionState({
                token0: makeAddr("token0"),
                token1: makeAddr("token1"),
                tickLower: -600,
                tickUpper: 600,
                currentTick: 0,
                tickSpacing: 60,
                liquidity: 1_000,
                amount0: 500,
                amount1: 500,
                fees0: 10,
                fees1: 20
            })
        );
    }

    function testOnlyKeeperCanExecute() public {
        vm.warp(1);
        ILPPositionAdapter.RebalanceParams memory params = _params(1_000, 2_000, 10, 0, 0);

        vm.prank(attacker);
        vm.expectRevert(LPPositionManager.NotKeeper.selector);
        manager.executeRebalance(positionId, params);
    }

    function testManagerEnforcesPerPositionBudget() public {
        vm.warp(1);
        ILPPositionAdapter.RebalanceParams memory params = _params(1_001, 2_000, 10, 0, 0);

        vm.prank(keeper);
        vm.expectRevert(LPPositionManager.Amount0LimitExceeded.selector);
        manager.executeRebalance(positionId, params);
    }

    function testManagerEnforcesAdapterSpendAndOutputFloors() public {
        vm.warp(1);
        adapter.setNextResult(
            ILPPositionAdapter.RebalanceResult({
                amount0Spent: 999,
                amount1Spent: 1_900,
                amount0Received: 100,
                amount1Received: 200,
                newLiquidity: 1_100
            })
        );

        ILPPositionAdapter.RebalanceParams memory params = _params(1_000, 2_000, 10, 99, 199);

        vm.prank(keeper);
        manager.executeRebalance(positionId, params);
    }

    function testManagerRejectsInsufficientOutput() public {
        vm.warp(1);
        adapter.setNextResult(
            ILPPositionAdapter.RebalanceResult({
                amount0Spent: 999,
                amount1Spent: 1_900,
                amount0Received: 98,
                amount1Received: 200,
                newLiquidity: 1_100
            })
        );

        ILPPositionAdapter.RebalanceParams memory params = _params(1_000, 2_000, 10, 99, 199);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(LPPositionManager.OutputTooLow.selector, 98, 200));
        manager.executeRebalance(positionId, params);
    }

    function testCooldownAppliesAfterSuccessfulRebalance() public {
        vm.warp(1);
        adapter.setNextResult(
            ILPPositionAdapter.RebalanceResult({
                amount0Spent: 1,
                amount1Spent: 1,
                amount0Received: 1,
                amount1Received: 1,
                newLiquidity: 1
            })
        );
        ILPPositionAdapter.RebalanceParams memory params = _params(10, 10, 10, 1, 1);

        vm.prank(keeper);
        manager.executeRebalance(positionId, params);

        vm.warp(50);
        vm.prank(keeper);
        vm.expectRevert(LPPositionManager.CooldownActive.selector);
        manager.executeRebalance(positionId, params);

        vm.warp(101);
        vm.prank(keeper);
        manager.executeRebalance(positionId, params);
    }

    function _params(
        uint256 max0,
        uint256 max1,
        uint16 slippage,
        uint256 out0,
        uint256 out1
    ) internal view returns (ILPPositionAdapter.RebalanceParams memory) {
        return ILPPositionAdapter.RebalanceParams({
            tickLower: -600,
            tickUpper: 600,
            slippageBps: slippage,
            amount0InMax: max0,
            amount1InMax: max1,
            amount0OutMin: out0,
            amount1OutMin: out1,
            deadline: block.timestamp + 100,
            venueData: ""
        });
    }
}
