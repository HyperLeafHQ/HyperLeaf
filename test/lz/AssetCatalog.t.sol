// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {LeafRedeemQueue} from "src/lz/LeafRedeemQueue.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockEndpoint is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 1;
    }

    function send(MessagingParams calldata, address) external payable returns (MessagingReceipt memory r) {
        r.guid = bytes32(uint256(1));
    }

    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee(0, 0);
    }

    function setDelegate(address) external {}

    function setConfig(address, address, SetConfigParam[] calldata) external {}

    function getConfig(address, address, uint32, uint32) external pure returns (bytes memory) {
        return "";
    }

    function skip(address, uint32, bytes32, uint64) external {}
}

contract AssetCatalogTest is Test {
    MockEndpoint ep;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);

    function setUp() public {
        ep = new MockEndpoint();
    }

    function testEveryListingConstructs() public {
        string[10] memory ids = AssetCatalog.allIds();
        for (uint256 i; i < ids.length; ++i) {
            AssetCatalog.Listing memory a = AssetCatalog.get(ids[i]);
            MockERC20 inner = new MockERC20(a.innerSymbol, a.innerSymbol);
            vm.startPrank(owner);
            if (a.kind == AssetCatalog.Kind.Liquid) {
                LeafOFTAdapter src =
                    new LeafOFTAdapter(address(inner), address(ep), owner, guardian, feeTo, a.defaultCap);
                LeafOFT oft = new LeafOFT(a.name, a.symbol, address(ep), owner, guardian);
                assertEq(address(src.innerToken()), address(inner));
                assertEq(oft.symbol(), a.symbol);
            } else if (a.kind == AssetCatalog.Kind.Closed) {
                LeafInboundLockbox src =
                    new LeafInboundLockbox(address(inner), address(ep), owner, guardian, feeTo, a.defaultCap);
                LeafClosedOFT oft =
                    new LeafClosedOFT(a.name, a.symbol, a.lockSeconds, address(ep), owner, guardian);
                assertEq(address(src.innerToken()), address(inner));
                assertEq(oft.lockSeconds(), a.lockSeconds);
                vm.expectRevert(LeafClosedOFT.ExitViaMarketOnly.selector);
                oft.send(1, bytes32(uint256(1)), 1, owner);
            } else {
                LeafRedeemQueue src = new LeafRedeemQueue(
                    address(inner), address(ep), owner, guardian, feeTo, a.defaultCap, a.redeemDelay
                );
                LeafOFT oft = new LeafOFT(a.name, a.symbol, address(ep), owner, guardian);
                assertEq(src.redeemDelay(), a.redeemDelay);
                assertEq(oft.symbol(), a.symbol);
            }
            vm.stopPrank();
        }
    }

    function testUnknownAssetReverts() public {
        vm.expectRevert(AssetCatalog.UnknownAsset.selector);
        this._get("nope");
    }

    function _get(string calldata id) external pure returns (AssetCatalog.Listing memory) {
        return AssetCatalog.get(id);
    }

    function testMainnetInnersSetForEvmAssets() public pure {
        assertTrue(AssetCatalog.get("hkaito").innerMainnet != address(0));
        assertTrue(AssetCatalog.get("hxsquid").innerMainnet != address(0));
        assertTrue(AssetCatalog.get("hcbeth").innerMainnet != address(0));
        assertEq(AssetCatalog.get("hcbeth").symbol, "hcbETH");
        assertEq(AssetCatalog.get("hcbeth").sourceChainIdMain, 8453);
        assertTrue(AssetCatalog.get("hwsteth").innerMainnet != address(0));
        assertEq(AssetCatalog.get("hwsteth").sourceChainIdMain, 1);
        assertTrue(AssetCatalog.get("hsavax").innerMainnet != address(0));
        assertTrue(AssetCatalog.get("hvirtualmax").innerMainnet != address(0));
        assertEq(AssetCatalog.get("virtual4y").id, "hvirtualmax");
        assertEq(AssetCatalog.get("hvirtualmax").symbol, "hVIRTUALMAX");
        assertTrue(AssetCatalog.get("bluai4y").innerMainnet != address(0));
        assertEq(AssetCatalog.get("bonk12m").innerMainnet, address(0));
        assertEq(AssetCatalog.get("hmet").innerMainnet, address(0));
        assertEq(AssetCatalog.get("hshmon").innerMainnet, address(0));
        assertTrue(AssetCatalog.get("hkaito").productionEvm);
        assertFalse(AssetCatalog.get("bonk12m").productionEvm);
    }
}
