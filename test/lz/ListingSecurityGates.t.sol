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

    function testProductionListingsHaveNoIntakeCap() public pure {
        string[15] memory ids = [
            "bluai4y",
            "horder",
            "hswbera",
            "hsavax",
            "hquid",
            "havnt",
            "hgsoon",
            "hvirtualmax",
            "hlbtc",
            "hveaero",
            "hjitosol",
            "hstkwausdc",
            "hkaito",
            "hcbeth",
            "hwsteth"
        ];
        for (uint256 i; i < ids.length; ++i) {
            assertEq(AssetCatalog.get(ids[i]).defaultCap, 0, ids[i]);
        }
    }
}
