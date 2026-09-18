// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LeafDaiPolicy} from "src/lz/LeafDaiPolicy.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

contract LeafDaiTest is Test {
    function testCatalogPinsShareNotDai() public pure {
        AssetCatalog.Listing memory a = AssetCatalog.get("hdai");
        assertEq(a.id, "hdai");
        assertEq(a.symbol, "hDAI");
        assertEq(a.innerSymbol, "gtDAIcore");
        assertEq(uint8(a.kind), uint8(AssetCatalog.Kind.Liquid));
        assertEq(a.sourceChainIdMain, 1);
        assertEq(a.sourceEidMain, 30101);
        assertEq(a.sourceEidTest, 40161);
        assertEq(a.innerMainnet, LeafDaiPolicy.GT_DAI_CORE);
        assertTrue(a.innerMainnet != LeafDaiPolicy.DAI);
        assertTrue(a.innerMainnet != LeafDaiPolicy.SDAI);
        assertTrue(a.innerMainnet != LeafDaiPolicy.TW_GT_DAI);
        assertEq(a.defaultCap, LeafDaiPolicy.SHARE_CAP);
        assertEq(a.defaultCap, 100_000e18);
        assertEq(a.lockSeconds, 0);
        assertTrue(a.productionEvm);
        assertEq(AssetCatalog.get("hDAI").id, "hdai");
        assertEq(LeafDaiPolicy.INNER_DECIMALS, 18);
        assertEq(LeafDaiPolicy.ASSET_DECIMALS, 18);
        assertEq(LeafDaiPolicy.CONVERT_TO_ASSETS_1E18_PROBE, 1_178_122_698_615_078_586);
        assertTrue(LeafDaiPolicy.CONVERT_TO_ASSETS_1E18_PROBE > 1e18);
        assertTrue(LeafDaiPolicy.CONVERT_TO_ASSETS_1E18_PROBE < 2e18);
    }

    function testRequireGtDaiCoreRejectsCousins() public {
        vm.expectRevert(LeafDaiPolicy.NotGtDaiCore.selector);
        this._require(LeafDaiPolicy.DAI);
        vm.expectRevert(LeafDaiPolicy.NotGtDaiCore.selector);
        this._require(LeafDaiPolicy.SDAI);
        vm.expectRevert(LeafDaiPolicy.NotGtDaiCore.selector);
        this._require(LeafDaiPolicy.TW_GT_DAI);
        vm.expectRevert(LeafDaiPolicy.NotGtDaiCore.selector);
        this._require(address(0));
        LeafDaiPolicy.requireGtDaiCore(LeafDaiPolicy.GT_DAI_CORE);
    }

    function testNotAMainnetBatch() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hdai");
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hDAI");
    }

    function testEthLzAlreadyPinned() public pure {
        assertEq(A.eidForChainId(1), A.EID_ETH);
        assertEq(A.EID_ETH, 30101);
        assertEq(A.confirmationsForEid(A.EID_ETH), A.CONFIRMATIONS_ETH);
        assertEq(A.endpoint(1), A.ENDPOINT_ETH);
    }

    function testErc4626SelectorsForbidden() public pure {
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xb460af94))); // withdraw
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xba087652))); // redeem
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x6e553f65))); // deposit
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x94bf804d))); // mint
    }

    function _require(address inner_) external pure {
        LeafDaiPolicy.requireGtDaiCore(inner_);
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }
}
