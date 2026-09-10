// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LeafSsuiPolicy} from "src/lz/LeafSsuiPolicy.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

contract LeafSsuiTest is Test {
    function testCatalogPins() public pure {
        AssetCatalog.Listing memory a = AssetCatalog.get("hssui");
        assertEq(a.innerMainnet, address(0));
        assertEq(a.sourceEidMain, LeafSsuiPolicy.EID);
        assertEq(a.sourceEidMain, A.EID_SUI);
        assertEq(a.sourceEidTest, A.EID_SUI_TESTNET);
        assertEq(a.defaultCap, 10 ether);
        assertFalse(a.productionEvm);
        assertEq(AssetCatalog.get("hsSUI").id, "hssui");
        assertEq(uint8(a.kind), uint8(AssetCatalog.Kind.Liquid));
        assertEq(uint256(LeafSsuiPolicy.INNER_DECIMALS), 9);
        assertEq(LeafSsuiPolicy.SHARE_SCALE, 1e9);
    }

    function testRequireSsuiRejectsRawSui() public {
        vm.expectRevert(LeafSsuiPolicy.NotSsui.selector);
        this._require(LeafSsuiPolicy.RAW_SUI);
        LeafSsuiPolicy.requireSsui(LeafSsuiPolicy.COIN_TYPE);
    }

    function _require(string calldata coinType) external pure {
        LeafSsuiPolicy.requireSsui(coinType);
    }

    function testNotThisBatch() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hssui");
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }

    function testNoSuiConfirmationsPinned() public {
        vm.expectRevert(bytes("lz: no confirmations"));
        this._confirms();
    }

    function _confirms() external pure returns (uint64) {
        return A.confirmationsForEid(A.EID_SUI);
    }
}
