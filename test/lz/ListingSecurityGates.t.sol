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

    function testHdaiIsCappedPilotNotUnlimited() public pure {
        AssetCatalog.Listing memory a = AssetCatalog.get("hdai");
        assertEq(a.id, "hdai");
        assertTrue(a.productionEvm);
        assertEq(a.defaultCap, 100_000e18);
        assertEq(a.sourceChainIdMain, 1);
        assertEq(a.innerMainnet, 0x500331c9fF24D9d11aee6B07734Aa72343EA74a5);
    }

    function testHinkIsNotProductionUntilOfficialInkExists() public pure {
        AssetCatalog.Listing memory a = AssetCatalog.get("hink");
        assertEq(a.id, "hink");
        assertFalse(a.productionEvm);
        assertEq(a.defaultCap, 0);
        assertEq(a.innerMainnet, address(0));
        assertEq(a.sourceChainIdMain, 57073);
    }

    function testProductionListingsHaveNoIntakeCap() public pure {
        string[19] memory ids = [
            "bluai4y",
            "horder",
            "hswbera",
            "hsibera",
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
            "hwsteth",
            "hslisbnb",
            "hink",
            "hsteakusdg"
        ];
        for (uint256 i; i < ids.length; ++i) {
            assertEq(AssetCatalog.get(ids[i]).defaultCap, 0, ids[i]);
        }
    }
}
