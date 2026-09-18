// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {LeafSecurity} from "src/lz/LeafSecurity.sol";
import {LeafSteakPolicy} from "src/lz/LeafSteakPolicy.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";

contract LeafSteakTest is Test {
    address constant NETHERMIND_RH = 0x0Ffe02DF012299A370D5dd69298A5826EAcaFdF8;

    function testCatalogPinsShareNotUsdg() public pure {
        AssetCatalog.Listing memory a = AssetCatalog.get("hsteakusdg");
        assertEq(a.id, "hsteakusdg");
        assertEq(a.symbol, "hsteakUSDG");
        assertEq(a.innerSymbol, "steakUSDG");
        assertEq(uint8(a.kind), uint8(AssetCatalog.Kind.Liquid));
        assertEq(a.sourceChainIdMain, 4663);
        assertEq(a.sourceEidMain, 30416);
        assertEq(a.sourceEidTest, 40451);
        assertEq(a.innerMainnet, LeafSteakPolicy.STEAK_USDG);
        assertTrue(a.innerMainnet != LeafSteakPolicy.USDG);
        assertTrue(a.innerMainnet != LeafSteakPolicy.STEAK_USDC);
        assertEq(a.defaultCap, 0);
        assertEq(a.lockSeconds, 0);
        assertTrue(a.productionEvm);
        assertEq(AssetCatalog.get("hsteakUSDG").id, "hsteakusdg");
        assertEq(LeafSteakPolicy.INNER_DECIMALS, 18);
        assertEq(LeafSteakPolicy.ASSET_DECIMALS, 6);
        assertEq(LeafSteakPolicy.CONVERT_TO_ASSETS_1E18_PROBE, 1_007_328);
        assertTrue(LeafSteakPolicy.CONVERT_TO_ASSETS_1E18_PROBE < 1e8);
        assertTrue(LeafSteakPolicy.CONVERT_TO_ASSETS_1E18_PROBE > 1e6);
    }

    function testRequireSteakUsdgRejectsCousins() public {
        vm.expectRevert(LeafSteakPolicy.NotSteakUsdg.selector);
        this._require(LeafSteakPolicy.USDG);
        vm.expectRevert(LeafSteakPolicy.NotSteakUsdg.selector);
        this._require(LeafSteakPolicy.STEAK_USDC);
        vm.expectRevert(LeafSteakPolicy.NotSteakUsdg.selector);
        this._require(address(0));
        LeafSteakPolicy.requireSteakUsdg(LeafSteakPolicy.STEAK_USDG);
    }

    function testNotAMainnetBatch() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hsteakusdg");
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hsteakUSDG");
    }

    function testRobinhoodLzIsBeraCreate2WithOwnDvns() public pure {
        assertEq(A.endpoint(4663), A.ENDPOINT_BERA);
        assertEq(A.ENDPOINT_BERA, 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B);
        assertEq(A.eidForChainId(4663), A.EID_ROBINHOOD);
        assertEq(A.EID_ROBINHOOD, 30416);
        assertEq(A.EID_ROBINHOOD_TESTNET, 40451);
        assertEq(A.confirmationsForEid(A.EID_ROBINHOOD), A.CONFIRMATIONS_ARB);
        assertEq(A.SEND_ULN_ROBINHOOD, A.SEND_ULN_BERA);
        assertEq(A.RECEIVE_ULN_ROBINHOOD, A.RECEIVE_ULN_BERA);
        assertEq(A.EXECUTOR_ROBINHOOD, A.EXECUTOR_BERA);
        assertEq(A.SEND_ULN_ROBINHOOD, 0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7);
        assertEq(A.RECEIVE_ULN_ROBINHOOD, 0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043);
        assertEq(A.EXECUTOR_ROBINHOOD, 0x4208D6E27538189bB48E603D6123A94b8Abe0A0b);
    }

    function testRobinhoodOptionalDvnsArePushV2Sorted() public pure {
        address[] memory d = LeafSecurity.robinhoodOptionalDvns();
        assertEq(d.length, 3);
        assertEq(d[0], A.DVN_HORIZEN_ROBINHOOD);
        assertEq(d[1], A.DVN_CANARY_ROBINHOOD);
        assertEq(d[2], A.DVN_LZ_LABS_ROBINHOOD);
        assertEq(d[0], 0x1258A278519c7f4bd997a9c3BFd4Aa802a028D89);
        assertEq(d[1], 0x8D77D35604A9f37f488E41D1d916b2A0088F82Dd);
        assertEq(d[2], 0xd01ae6905d48315f7bE10C7330aeCF8360Ef5b12);
        assertTrue(uint160(d[0]) < uint160(d[1]));
        assertTrue(uint160(d[1]) < uint160(d[2]));
        assertTrue(d[0] != NETHERMIND_RH && d[1] != NETHERMIND_RH && d[2] != NETHERMIND_RH);
        assertTrue(d[0] != A.DVN_HORIZEN_BERA);
        assertTrue(d[1] != A.DVN_CANARY_BERA);
        assertTrue(d[2] != A.DVN_LZ_LABS_BERA);
    }

    function testErc4626SelectorsForbidden() public pure {
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xb460af94))); // withdraw
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xba087652))); // redeem
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x6e553f65))); // deposit
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x94bf804d))); // mint
    }

    function _require(address inner_) external pure {
        LeafSteakPolicy.requireSteakUsdg(inner_);
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }
}
