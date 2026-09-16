// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {LeafSecurity} from "src/lz/LeafSecurity.sol";

contract LeafInkTest is Test {
    address constant SUSDM = 0x5f1ab62C3159eBE04aFF14Beef84b0b60de63DDF;
    bytes32 constant NADO_N3 = 0x9486988cc36ef76e88b1607554932525fbefc3a2101c4dde123fe67fd22e3bca;

    function testHinkPinsAreInkAndNotProduction() public pure {
        AssetCatalog.Listing memory a = AssetCatalog.get("hink");
        assertEq(a.id, "hink");
        assertEq(a.symbol, "hINK");
        assertEq(a.innerSymbol, "INK");
        assertEq(uint8(a.kind), uint8(AssetCatalog.Kind.Liquid));
        assertEq(a.sourceChainIdMain, 57073);
        assertEq(a.sourceEidMain, 30339);
        assertEq(a.sourceEidTest, 40358);
        assertEq(a.innerMainnet, address(0));
        assertEq(a.defaultCap, 0);
        assertFalse(a.productionEvm);
        assertEq(AssetCatalog.get("hINK").id, "hink");
    }

    function testHinkIsNotAMainnetBatch() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hink");
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hINK");
    }

    function testInkLzIsNotCreate2() public pure {
        assertEq(A.endpoint(57073), A.ENDPOINT_INK);
        assertTrue(A.ENDPOINT_INK != A.ENDPOINT_ETH);
        assertEq(A.eidForChainId(57073), A.EID_INK);
        assertEq(A.EID_INK, 30339);
        assertEq(A.confirmationsForEid(A.EID_INK), A.CONFIRMATIONS_OP);
        assertEq(A.SEND_ULN_INK, 0x76111DE813F83AAAdBD62773Bf41247634e2319a);
        assertEq(A.RECEIVE_ULN_INK, 0x473132bb594caEF281c68718F4541f73FE14Dc89);
        assertEq(A.EXECUTOR_INK, 0xFEbCF17b11376C724AB5a5229803C6e838b6eAe5);
    }

    function testInkOptionalDvnsArePushV2Sorted() public pure {
        address[] memory d = LeafSecurity.inkOptionalDvns();
        assertEq(d.length, 3);
        assertEq(d[0], A.DVN_LZ_LABS_INK);
        assertEq(d[1], A.DVN_CANARY_INK);
        assertEq(d[2], A.DVN_HORIZEN_INK);
        assertTrue(uint160(d[0]) < uint160(d[1]));
        assertTrue(uint160(d[1]) < uint160(d[2]));
    }

    function testNadoMarketIdIsN3() public pure {
        bytes32 id = keccak256(abi.encode("Nado points", SUSDM, uint256(3)));
        assertEq(id, NADO_N3);
        // Sanity: Predict n=2 pin still holds so n=3 is the next slot.
        bytes32 predict = keccak256(abi.encode("Predict points", SUSDM, uint256(2)));
        assertEq(predict, bytes32(0x1baea95474393f109b379c6ac2ee649bffc9bde2d8a908400018c9cf69a9f23e));
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }
}
