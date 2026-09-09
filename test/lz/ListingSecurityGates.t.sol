// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";

contract ListingSecurityGatesTest is Test {
    function testHsEthfiIsNotProductionEvmUntilDedicatedAccountingExists() public pure {
        AssetCatalog.Listing memory a = AssetCatalog.get("hsethfi");
        assertEq(a.id, "hsethfi");
        assertFalse(a.productionEvm);
        assertEq(a.defaultCap, 0);
    }

    function testHstkwaUsdcNeverFallsBackToOneThousandEtherCap() public pure {
        AssetCatalog.Listing memory a = AssetCatalog.get("hstkwausdc");
        assertEq(a.defaultCap, 0);
    }
}
