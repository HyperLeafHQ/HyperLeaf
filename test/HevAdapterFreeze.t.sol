// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/StdStorage.sol";
import {HevAdapter} from "../src/HevAdapter.sol";

contract HevAdapterFreezeTest is Test {
    using stdStorage for StdStorage;

    HevAdapter adapter;

    function setUp() public {
        adapter = new HevAdapter(
            makeAddr("ve"),
            makeAddr("voter"),
            makeAddr("hype"),
            makeAddr("vault"),
            makeAddr("vr"),
            makeAddr("dist"),
            1
        );
    }

    function test_SetHevStrategyOkBeforeDeposits() public {
        adapter.setHevStrategy(makeAddr("s2"));
        assertEq(adapter.hevStrategy(), makeAddr("s2"));
    }

    function test_SetHevStrategyFrozenAfterDeposit() public {
        stdstore.target(address(adapter)).sig("depositedCount()").checked_write(uint256(1));
        vm.expectRevert(HevAdapter.StrategyChangeWhileDeposited.selector);
        adapter.setHevStrategy(makeAddr("evil"));
    }
}
