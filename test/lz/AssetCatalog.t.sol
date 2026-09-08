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
import {TestnetCatalog} from "src/lz/TestnetCatalog.sol";
import {NextTestnetCatalog} from "src/lz/NextTestnetCatalog.sol";
import {TestnetListings} from "src/lz/TestnetListings.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
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
        string[14] memory ids = AssetCatalog.allIds();
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
        assertEq(uint8(AssetCatalog.get("hgsoon").kind), uint8(AssetCatalog.Kind.Liquid));
        assertEq(AssetCatalog.get("hgsoon").innerMainnet, 0xcC48B55F6c16d4248EC6D78c11Ba19c1183Fe0F7);
        assertEq(AssetCatalog.get("hgsoon").sourceChainIdMain, 56);
        assertEq(uint8(AssetCatalog.get("hswbera").kind), uint8(AssetCatalog.Kind.Liquid));
        assertEq(AssetCatalog.get("hswbera").innerMainnet, 0x118D2cEeE9785eaf70C15Cd74CD84c9f8c3EeC9a);
        assertEq(AssetCatalog.get("hswbera").sourceEidMain, 30362);
        assertEq(AssetCatalog.get("hswbera").sourceEidTest, 40371);
        assertEq(AssetCatalog.get("hswbera").lockSeconds, 0);
        assertEq(AssetCatalog.get("hstkwausdc").innerMainnet, 0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6);
        assertEq(AssetCatalog.get("hstkwaUSDC").id, "hstkwausdc");
        assertEq(AssetCatalog.get("hstkwausdc").sourceChainIdMain, 1);
        assertEq(AssetCatalog.get("hstkwausdc").sourceEidTest, 40161);
    }

    function testRound1CatalogStillLocksHgsoon() public {
        vm.expectRevert(TestnetCatalog.NotThisRound.selector);
        this._round1("hgsoon");
        vm.expectRevert(TestnetCatalog.NotThisRound.selector);
        this._round1("hsavax");
        vm.expectRevert(TestnetCatalog.NotThisRound.selector);
        this._round1("hstkwausdc");
        AssetCatalog.Listing memory a = TestnetCatalog.get("hxsquid");
        assertEq(a.id, "hxsquid");
    }

    function testNextCatalogHgsoonOnly() public {
        AssetCatalog.Listing memory g = NextTestnetCatalog.get("hgsoon");
        assertEq(g.innerMainnet, 0xcC48B55F6c16d4248EC6D78c11Ba19c1183Fe0F7);
        assertEq(g.sourceEidTest, 40102);
        assertEq(uint8(g.kind), uint8(AssetCatalog.Kind.Liquid));
        vm.expectRevert(NextTestnetCatalog.NotThisRound.selector);
        this._next("hxsquid");
        assertEq(NextTestnetCatalog.get("hsavax").sourceEidTest, 40106);
        assertEq(NextTestnetCatalog.get("hstkwausdc").innerMainnet, 0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6);
        assertEq(TestnetListings.get("hgsoon").id, "hgsoon");
        assertEq(TestnetListings.get("hsavax").id, "hsavax");
        assertEq(TestnetListings.get("hstkwausdc").id, "hstkwausdc");
        assertEq(TestnetListings.get("bluai4y").id, "bluai4y");
    }

    function _round1(string calldata id) external pure returns (AssetCatalog.Listing memory) {
        return TestnetCatalog.get(id);
    }

    function _next(string calldata id) external pure returns (AssetCatalog.Listing memory) {
        return NextTestnetCatalog.get(id);
    }

    function testBepoliaHasNoLzEndpoint() public {
        vm.expectRevert(bytes("lz: Bepolia EndpointV2 not deployed"));
        this._endpoint(80069);
        assertEq(this._endpoint(43113), A.ENDPOINT_BASE_SEPOLIA);
        assertEq(this._endpoint(11155111), A.ENDPOINT_BASE_SEPOLIA);
    }

    function _endpoint(uint256 chainId) external pure returns (address) {
        return A.endpoint(chainId);
    }
}
