// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILPPositionAdapter} from "../../src/interfaces/ILPPositionAdapter.sol";

contract MockLPPositionAdapter is ILPPositionAdapter {
    address public immutable manager;
    PositionState private state;
    RebalanceResult public nextResult;

    error OnlyManager();

    constructor(address _manager) {
        manager = _manager;
    }

    modifier onlyManager() {
        if (msg.sender != manager) revert OnlyManager();
        _;
    }

    function setState(PositionState calldata newState) external {
        state = newState;
    }

    function setNextResult(RebalanceResult calldata result) external {
        nextResult = result;
    }

    function positionState(bytes32) external view returns (PositionState memory) {
        return state;
    }

    function rebalance(bytes32, RebalanceParams calldata) external onlyManager returns (RebalanceResult memory result) {
        result = nextResult;
        state.tickLower = result.newLiquidity == 0 ? state.tickLower : state.tickLower;
    }

    function collectFees(bytes32, bytes calldata) external onlyManager returns (uint256 amount0, uint256 amount1) {
        amount0 = state.fees0;
        amount1 = state.fees1;
        state.fees0 = 0;
        state.fees1 = 0;
    }
}
