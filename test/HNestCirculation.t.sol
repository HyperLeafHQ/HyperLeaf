// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HNestCirculation} from "../src/HNestCirculation.sol";

contract HNestCirculationTest is Test {
    function testThursdayEpochAlignsWithUnix() public pure {
        assertEq(HNestCirculation.epochEnd(0), 7 days);
        assertEq(HNestCirculation.epochEnd(1), 7 days);
        assertEq(HNestCirculation.epochEnd(7 days - 1), 7 days);
        assertEq(HNestCirculation.epochEnd(7 days), 14 days);
    }

    function testClaimableAtIsMaxOfEightDayDelayAndEpochSettlement() public pure {
        uint256 thu = 0;
        assertEq(HNestCirculation.claimableAt(thu), thu + 8 days);
        assertGt(HNestCirculation.claimableAt(thu), HNestCirculation.epochEnd(thu));

        uint256 wed = 6 days;
        assertEq(HNestCirculation.claimableAt(wed), wed + 8 days);
        assertGt(HNestCirculation.claimableAt(wed), HNestCirculation.epochEnd(wed) + 30 minutes);
    }

    function testFourDayHevLockIsNeverCirculation() public pure {
        uint256 depositTs = 1 days;
        uint256 hevUnlock = depositTs + 4 days;
        uint256 claimable = HNestCirculation.claimableAt(depositTs);
        assertLt(hevUnlock, claimable);
        assertEq(claimable, depositTs + 8 days);
    }

    function testNeverEarlierThanEightDays() public pure {
        for (uint256 i; i < 7; i++) {
            uint256 ts = i * 1 days + 123;
            assertGe(HNestCirculation.claimableAt(ts), ts + 8 days);
            assertGe(HNestCirculation.claimableAt(ts), HNestCirculation.epochEnd(ts) + 30 minutes);
        }
    }
}
