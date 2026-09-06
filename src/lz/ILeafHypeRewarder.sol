// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILeafHypeRewarder {
    function settle(bytes32 id, address user) external;
    function updateDebt(bytes32 id, address user) external;
}
