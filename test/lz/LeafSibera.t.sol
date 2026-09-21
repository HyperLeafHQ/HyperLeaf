// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LeafSiberaPolicy} from "src/lz/LeafSiberaPolicy.sol";

contract LeafSiberaTest is Test {
    function testCatalogPins() public pure {
        AssetCatalog.Listing memory a = AssetCatalog.get("hsibera");
        assertEq(a.id, "hsibera");
        assertEq(a.symbol, "hsiBERA");
        assertEq(a.innerSymbol, "siBERA");
        assertEq(a.innerMainnet, LeafSiberaPolicy.SIBERA);
        assertEq(a.sourceChainIdMain, 80094);
        assertEq(a.sourceEidMain, 30362);
        assertEq(a.sourceEidTest, 40371);
        assertEq(a.defaultCap, 0);
        assertTrue(a.productionEvm);
        assertEq(AssetCatalog.get("hsiBERA").id, "hsibera");
        assertEq(MainnetBatches.batchOf("hsibera"), 2);
        assertEq(MainnetBatches.batchOf("hsiBERA"), 2);
    }

    function testParkedSwberaIsNotProduction() public pure {
        AssetCatalog.Listing memory s = AssetCatalog.get("hswbera");
        assertEq(s.innerMainnet, LeafSiberaPolicy.SWBERA);
        assertFalse(s.productionEvm);
        assertTrue(s.innerMainnet != LeafSiberaPolicy.SIBERA);
    }

    function testRequireSiberaRejectsCousins() public {
        vm.expectRevert(LeafSiberaPolicy.NotSibera.selector);
        this._require(LeafSiberaPolicy.SWBERA);
        vm.expectRevert(LeafSiberaPolicy.NotSibera.selector);
        this._require(LeafSiberaPolicy.IBERA);
        vm.expectRevert(LeafSiberaPolicy.NotSibera.selector);
        this._require(LeafSiberaPolicy.WBERA);
        LeafSiberaPolicy.requireSibera(LeafSiberaPolicy.SIBERA);
    }

    function _require(address inner) external pure {
        LeafSiberaPolicy.requireSibera(inner);
    }
}
