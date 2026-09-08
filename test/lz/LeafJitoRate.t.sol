// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafJitoRate} from "src/lz/LeafJitoRate.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LeafJitoPolicy} from "src/lz/LeafJitoPolicy.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";
import {OptionsBuilder} from "src/lz/OptionsBuilder.sol";

contract MockJitoEndpoint is ILayerZeroEndpointV2 {
    bytes public lastOptions;
    uint32 public lastDstEid;
    bytes32 public lastPeer;
    uint32 public eid = 30367;

    function send(MessagingParams calldata p, address) external payable returns (MessagingReceipt memory r) {
        lastOptions = p.options;
        lastDstEid = p.dstEid;
        lastPeer = p.receiver;
        r.guid = keccak256(abi.encode(p, block.number));
        r.nonce = 1;
        r.fee = MessagingFee(msg.value, 0);
    }

    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee(0.01 ether, 0);
    }

    function setDelegate(address) external {}
    function setConfig(address, address, SetConfigParam[] calldata) external {}
    function getConfig(address, address, uint32, uint32) external pure returns (bytes memory) {
        return "";
    }
    function skip(address, uint32, bytes32, uint64) external {}

    function deliver(address oapp, Origin calldata origin, bytes calldata message) external {
        LeafOFT(payable(oapp)).lzReceive(origin, bytes32(uint256(1)), message, address(this), "");
    }
}

contract LeafJitoRateTest is Test, PegReady {
    function testRateMatchesPoolRatio() public pure {
        uint64 lamports = 10_254_350_600_000_000;
        uint64 supply = 7_889_287_950_000_000;
        uint256 r = LeafJitoRate.rate(lamports, supply);
        assertGt(r, 1.29e18);
        assertLt(r, 1.31e18);
    }

    function testRetainFeeOnePercentOfSurplus() public pure {
        uint256 accounted = 100e9; // 100 JitoSOL
        uint256 r0 = 1e18;
        uint256 r1 = 1.1e18;
        (uint256 fee, uint256 next, uint256 nr) = LeafJitoRate.bookRetainFee(accounted, r0, r1);
        // surplus = 100e9 * 0.1e18 / 1.1e18 = 9_090_909_090
        // fee 1% = 90_909_090
        assertEq(fee, 90_909_090);
        assertEq(next, accounted - fee);
        assertEq(nr, r1);
    }

    function testSlashDropsWatermarkNoFee() public pure {
        (uint256 fee, uint256 next, uint256 nr) = LeafJitoRate.bookRetainFee(100e9, 1.1e18, 1.05e18);
        assertEq(fee, 0);
        assertEq(next, 100e9);
        assertEq(nr, 1.05e18);
    }

    function testDustSurplusZeroFeeWatermarkMoves() public pure {
        // surplus = 1 * 0.1e18 / 1.1e18 = 0 → fee 0, rate still updates
        (uint256 fee, uint256 next, uint256 nr) = LeafJitoRate.bookRetainFee(1, 1e18, 1.1e18);
        assertEq(fee, 0);
        assertEq(next, 1);
        assertEq(nr, 1.1e18);
        // surplus = 1089/11 = 99 atoms → 99 * 100 / 10000 = 0
        (fee, next, nr) = LeafJitoRate.bookRetainFee(1089, 1e18, 1.1e18);
        assertEq(fee, 0);
        assertEq(next, 1089);
        assertEq(nr, 1.1e18);
        // surplus = 1100/11 = 100 → fee 1 atom
        (fee, next, nr) = LeafJitoRate.bookRetainFee(1100, 1e18, 1.1e18);
        assertEq(fee, 1);
        assertEq(next, 1099);
    }

    function testDonationDoesNotCreateFee() public pure {
        (uint256 fee,,) = LeafJitoRate.bookRetainFee(100e9, 1e18, 1e18);
        assertEq(fee, 0);
    }

    function testShareRoundTripFirstDeposit() public pure {
        uint256 atoms = 5e9;
        uint256 shares = LeafJitoRate.sharesForAtoms(atoms, 0, 0);
        assertEq(shares, 5e18);
        uint256 back = LeafJitoRate.atomsFromShares(shares, atoms, shares);
        assertEq(back, atoms);
    }

    function testRedeemAfterSkimIsProRataRemaining() public pure {
        uint256 atoms = 100e9;
        uint256 shares = LeafJitoRate.sharesFromAtoms(atoms);
        (uint256 fee, uint256 remaining,) = LeafJitoRate.bookRetainFee(atoms, 1e18, 1.1e18);
        uint256 out = LeafJitoRate.atomsFromShares(shares, remaining, shares);
        assertEq(out, remaining);
        assertLt(out, atoms);
        assertEq(atoms - out, fee);
    }

    function testListingTagMatchesKeccak() public pure {
        assertEq(LeafJitoPolicy.LISTING_TAG, keccak256("hjitosol"));
        assertTrue(LeafJitoPolicy.isForbiddenProgram(LeafJitoPolicy.VAULT_PROGRAM));
        assertTrue(LeafJitoPolicy.isForbiddenProgram(LeafJitoPolicy.RESTAKING_PROGRAM));
        assertTrue(LeafJitoPolicy.isForbiddenProgram(LeafJitoPolicy.STAKE_POOL_PROGRAM));
        assertFalse(LeafJitoPolicy.isForbiddenProgram(bytes32(uint256(1))));
    }

    function testHarvestOtherRejectsJitoMint() public {
        vm.expectRevert(LeafJitoPolicy.CannotHarvestInner.selector);
        this._harvestOther(LeafJitoPolicy.JITO_MINT);
        LeafJitoPolicy.requireHarvestOther(bytes32(uint256(2)));
    }

    function _harvestOther(bytes32 mint) external pure {
        LeafJitoPolicy.requireHarvestOther(mint);
    }

    function testPayloadIsAbiEncodeTagToAmount() public {
        AssetCatalog.Listing memory a = AssetCatalog.get("hjitosol");
        assertEq(a.sourceEidMain, A.EID_SOLANA);
        assertEq(a.innerMainnet, address(0));
        assertFalse(a.productionEvm);
        assertEq(MainnetBatches.batchOf("hjitosol"), 5);
        bytes32 tag = LeafJitoPolicy.LISTING_TAG;
        assertEq(tag, keccak256("hjitosol"));
        bytes32 to = bytes32(uint256(uint160(address(0xBEEF))));
        uint256 amount = 1e18;
        bytes memory payload = abi.encode(tag, to, amount);
        (bytes32 t, bytes32 u, uint256 n) = abi.decode(payload, (bytes32, bytes32, uint256));
        assertEq(t, tag);
        assertEq(u, to);
        assertEq(n, amount);
        assertEq(payload.length, 96);
        assertEq(bytes1(payload[95]), bytes1(0x00));
        assertEq(uint8(payload[88]), 0x0d);
    }

    function testSolanaConfirmationsAre32() public pure {
        assertEq(A.confirmationsForEid(A.EID_SOLANA), 32);
        assertEq(A.confirmationsForEid(A.EID_HYPEREVM), 5);
        assertEq(A.LZ_RECEIVE_SOLANA_CU, 400_000);
    }

    function testJupsolNotBatchFive() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hjupsol");
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }

    function testSolanaDvnTrioRejectsNethermind() public {
        LeafJitoPolicy.requireSolanaDvn(LeafJitoPolicy.DVN_LABS_SOLANA);
        LeafJitoPolicy.requireSolanaDvn(LeafJitoPolicy.DVN_HORIZEN_SOLANA);
        LeafJitoPolicy.requireSolanaDvn(LeafJitoPolicy.DVN_CANARY_SOLANA);
        vm.expectRevert(LeafJitoPolicy.BadSolanaDvn.selector);
        this._dvn(LeafJitoPolicy.DVN_NETHERMIND_SOLANA);
        vm.expectRevert(LeafJitoPolicy.NotSolanaPeer.selector);
        this._peer(bytes32(uint256(uint160(address(0xBEEF)))));
        LeafJitoPolicy.requireSolanaPeer(bytes32(uint256(1) << 255));
    }

    function _dvn(bytes32 d) external pure {
        LeafJitoPolicy.requireSolanaDvn(d);
    }

    function _peer(bytes32 p) external pure {
        LeafJitoPolicy.requireSolanaPeer(p);
    }
}

contract LeafJitoDestOFTTest is PegReady {
    MockJitoEndpoint ep;
    LeafOFT oft;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address user = address(0xCAFE);
    bytes32 solanaStore = bytes32(uint256(1) << 255);
    bytes32 solanaWallet = bytes32(uint256(2) << 200);

    function setUp() public {
        ep = new MockJitoEndpoint();
        vm.prank(owner);
        oft = new LeafOFT("Hyperleaf JitoSOL", "hJitoSOL", address(ep), owner, guardian);
        vm.startPrank(owner);
        oft.setPeer(A.EID_SOLANA, solanaStore);
        oft.setListingTag(LeafJitoPolicy.LISTING_TAG);
        oft.setLimits(10 ether, 10 ether);
        oft.setSupplyCap(10 ether);
        oft.openBridge();
        vm.stopPrank();
        vm.deal(user, 1 ether);
        assertEq(address(oft.hypeRewarder()), address(0));
    }

    function testMintFromSolanaPayload() public {
        bytes memory payload = abi.encode(LeafJitoPolicy.LISTING_TAG, bytes32(uint256(uint160(user))), 1 ether);
        ILayerZeroEndpointV2.Origin memory origin =
            ILayerZeroEndpointV2.Origin({srcEid: A.EID_SOLANA, sender: solanaStore, nonce: 1});
        ep.deliver(address(oft), origin, payload);
        assertEq(oft.balanceOf(user), 1 ether);
    }

    function testWrongTagFromSolanaReverts() public {
        bytes memory payload = abi.encode(keccak256("nope"), bytes32(uint256(uint160(user))), 1 ether);
        ILayerZeroEndpointV2.Origin memory origin =
            ILayerZeroEndpointV2.Origin({srcEid: A.EID_SOLANA, sender: solanaStore, nonce: 1});
        vm.expectRevert(LeafOApp.WrongListing.selector);
        ep.deliver(address(oft), origin, payload);
    }

    function testSendToSolanaRejectsEvmPadding() public {
        // mint first
        bytes memory payload = abi.encode(LeafJitoPolicy.LISTING_TAG, bytes32(uint256(uint160(user))), 2 ether);
        ILayerZeroEndpointV2.Origin memory origin =
            ILayerZeroEndpointV2.Origin({srcEid: A.EID_SOLANA, sender: solanaStore, nonce: 1});
        ep.deliver(address(oft), origin, payload);

        vm.startPrank(user);
        vm.expectRevert(LeafOApp.NotSolanaRecipient.selector);
        oft.sendTo{value: 0.01 ether}(A.EID_SOLANA, user, 1 ether);
        oft.send{value: 0.01 ether}(A.EID_SOLANA, solanaWallet, 1 ether, user);
        vm.stopPrank();
        assertEq(oft.balanceOf(user), 1 ether);
        assertEq(ep.lastDstEid(), A.EID_SOLANA);
        assertEq(ep.lastOptions(), OptionsBuilder.lzReceiveOption(A.LZ_RECEIVE_SOLANA_CU));
    }

    function testQuoteSendSolanaNeedsPubkey() public {
        vm.expectRevert(LeafOApp.NotSolanaRecipient.selector);
        oft.quoteSend(A.EID_SOLANA, user, 1 ether);
        uint256 fee = oft.quoteSend(A.EID_SOLANA, solanaWallet, 1 ether);
        assertEq(fee, 0.01 ether);
    }
}
