// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PreMarketFactory} from "src/premarket/PreMarketFactory.sol";
import {MultisigResolver} from "src/premarket/MultisigResolver.sol";
import {ClaimSeriesToken} from "src/premarket/ClaimSeriesToken.sol";
import {DeliveryLockbox} from "src/premarket/DeliveryLockbox.sol";
import {EscrowVault} from "src/premarket/EscrowVault.sol";
import {PremarketOriginLock} from "src/premarket/PremarketOriginLock.sol";
import {PremarketSameChainHub} from "src/premarket/PremarketSameChainHub.sol";
import {PremarketLzHub} from "src/premarket/PremarketLzHub.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockUsdm is ERC20 {
    constructor() ERC20("USDM", "USDM") {}
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

/// @dev 12-dec 4626 like sUSDM. rate is USDM (6d) per 1e12 shares.
contract MockSusdm is ERC20 {
    MockUsdm public immutable assetToken;
    uint256 public rate = 1e6; // 1e12 shares = 1e6 USDM

    constructor(MockUsdm a) ERC20("sUSDM", "sUSDM") {
        assetToken = a;
    }

    function decimals() public pure override returns (uint8) {
        return 12;
    }

    function asset() external view returns (address) {
        return address(assetToken);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return (shares * rate) / 1e12;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return (assets * 1e12) / rate;
    }

    function deposit(uint256 assets, address to) external returns (uint256 shares) {
        shares = convertToShares(assets);
        if (convertToAssets(shares) < assets) shares += 1;
        require(assetToken.transferFrom(msg.sender, address(this), assets), "usdm");
        _mint(to, shares);
    }

    function mintShares(address to, uint256 shares) external {
        _mint(to, shares);
    }

    function setRate(uint256 r) external {
        rate = r;
    }
}

contract MockVar is ERC20 {
    constructor() ERC20("VAR", "VAR") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract PreMarketTest is Test {
    PreMarketFactory factory;
    MultisigResolver resolver;
    MockUsdm usdm;
    MockSusdm susdm;
    MockVar varTok;
    address owner = address(0xA11CE);
    address fee = address(0xFEE);
    address bob = address(0xB0B);
    address alice = address(0xA11);
    bytes32 marketId;
    bytes32 seriesId;

    function setUp() public {
        resolver = new MultisigResolver(owner);
        factory = new PreMarketFactory(owner, address(resolver), fee);
        usdm = new MockUsdm();
        susdm = new MockSusdm(usdm);
        varTok = new MockVar();
        vm.prank(owner);
        marketId = factory.createMarket("Variational points", "Var", address(susdm));
        usdm.mint(bob, 20_000e6);
        usdm.mint(alice, 20_000e6);
        vm.startPrank(bob);
        usdm.approve(address(factory), type(uint256).max);
        seriesId = factory.createSeries(marketId, 20_000, 20e18);
        factory.depositAndMint(seriesId, 100e18, type(uint256).max);
        vm.stopPrank();
        vm.prank(alice);
        usdm.approve(address(factory), type(uint256).max);
    }

    function testTickerAndFloor() public view {
        address tok = factory.seriesClaim(seriesId);
        assertEq(ClaimSeriesToken(tok).symbol(), "hPreVarPts2x20");
        assertEq(factory.seriesUnit(seriesId), 40e6);
        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.OPEN));
    }

    function testClaimTokenIsEip1167Clone() public {
        address impl = factory.claimImpl();
        vm.expectRevert(ClaimSeriesToken.AlreadyInit.selector);
        ClaimSeriesToken(impl).initialize(address(factory), "x", "y");
        address tok = factory.seriesClaim(seriesId);
        assertEq(ClaimSeriesToken(tok).factory(), address(factory));
        assertLt(tok.code.length, 60);
        assertTrue(impl.code.length > tok.code.length);
    }

    function testOneXAndRejectThreeX() public {
        vm.prank(bob);
        bytes32 s1 = factory.createSeries(marketId, 10_000, 20e18);
        assertEq(factory.seriesUnit(s1), 20e6);
        assertEq(ClaimSeriesToken(factory.seriesClaim(s1)).symbol(), "hPreVarPts1x20");
        vm.prank(bob);
        vm.expectRevert(PreMarketFactory.BadTier.selector);
        factory.createSeries(marketId, 30_000, 20e18);
    }

    function testPreviewOneXTwentyUsesNavNotShareCount() public {
        vm.prank(bob);
        bytes32 s1 = factory.createSeries(marketId, 10_000, 20e18);
        (uint256 assets, uint256 shares) = factory.previewDepositAndMint(s1, 1e18);
        assertEq(assets, 20e6);
        assertEq(shares, 20e12);
        (uint256 buyA, uint256 buyS) = factory.previewBuy(s1, 1e18);
        assertEq(buyA, 20e6);
        assertEq(buyS, 20e12);

        susdm.setRate(1_100_000);
        (uint256 a2, uint256 s2) = factory.previewDepositAndMint(s1, 1e18);
        assertEq(a2, 20e6);
        uint256 raw = (uint256(20e6) * 1e12) / 1_100_000;
        if (susdm.convertToAssets(raw) < 20e6) raw += 1;
        assertEq(s2, raw);
    }

    function testMaxSharesProtectsStaleQuote() public {
        vm.prank(bob);
        bytes32 s1 = factory.createSeries(marketId, 10_000, 20e18);
        (, uint256 quoted) = factory.previewDepositAndMint(s1, 1e18);
        vm.prank(bob);
        vm.expectRevert(EscrowVault.Slippage.selector);
        factory.depositAndMint(s1, 1e18, quoted - 1);
        vm.prank(bob);
        factory.depositAndMint(s1, 1e18, quoted);
    }

    function testNavDropDoesNotFreezeNewSeries() public {
        susdm.setRate(900_000);
        vm.startPrank(bob);
        bytes32 s1 = factory.createSeries(marketId, 10_000, 20e18);
        factory.depositAndMint(s1, 1e18, type(uint256).max);
        vm.stopPrank();
        assertEq(factory.vaultOf(marketId).collateralOf(s1), 20e6);
        assertGt(factory.vaultOf(marketId).sharesOf(s1), 0);
    }

    function testBuyMaxSharesProtectsStaleQuote() public {
        (, uint256 quoted) = factory.previewBuy(seriesId, 1e18);
        vm.prank(alice);
        vm.expectRevert(EscrowVault.Slippage.selector);
        factory.buyFromSeries(seriesId, 1e18, quoted - 1);
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 1e18, quoted);
        assertEq(ClaimSeriesToken(factory.seriesClaim(seriesId)).balanceOf(alice), 1e18);
    }

    function testAnyDealPrice() public {
        vm.prank(bob);
        bytes32 odd = factory.createSeries(marketId, 20_000, 17e18);
        assertEq(ClaimSeriesToken(factory.seriesClaim(odd)).symbol(), "hPreVarPts2x17");
        assertEq(factory.seriesUnit(odd), 34e6);
    }

    function testPrimaryFillThenDeliver() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18, type(uint256).max);
        address tok = factory.seriesClaim(seriesId);
        assertEq(ClaimSeriesToken(tok).balanceOf(alice), 100e18);
        assertEq(factory.vaultOf(marketId).escrowOf(seriesId), 2_000e6);

        vm.prank(owner);
        resolver.resolve(marketId, uint64(block.chainid), address(varTok), 18, 1e18);
        factory.resolve(seriesId);
        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.RESOLVED));

        varTok.mint(bob, 100e18);
        vm.startPrank(bob);
        varTok.approve(address(factory), type(uint256).max);
        factory.deliver(seriesId, 100e18);
        vm.stopPrank();
        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.SETTLED));

        vm.prank(alice);
        factory.redeemPull(seriesId);
        assertEq(varTok.balanceOf(alice), 100e18);

        uint256 bobBefore = susdm.balanceOf(bob);
        vm.prank(bob);
        factory.withdrawSettlement(seriesId);
        assertGt(susdm.balanceOf(bob), bobBefore);
    }

    function testDefaultPaysHoldersNotSellerHeld() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18, type(uint256).max);
        address claim = factory.seriesClaim(seriesId);
        vm.prank(alice);
        ClaimSeriesToken(claim).transfer(bob, 40e18);

        vm.prank(owner);
        resolver.resolve(marketId, uint64(block.chainid), address(varTok), 18, 1e18);
        factory.resolve(seriesId);
        vm.warp(block.timestamp + 49 hours);
        factory.finalize(seriesId);

        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.DEFAULTED));
        assertEq(factory.seriesFinalSold(seriesId), 60e18);
        assertEq(ClaimSeriesToken(factory.seriesClaim(seriesId)).balanceOf(bob), 0);

        uint256 aliceShares = susdm.balanceOf(alice);
        vm.prank(alice);
        factory.redeemPull(seriesId);
        assertGt(susdm.balanceOf(alice), aliceShares);
    }

    function testVoidRefundsBoth() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18, type(uint256).max);
        vm.prank(owner);
        resolver.voidMarket(marketId);
        factory.voidSeries(seriesId);
        vm.prank(alice);
        factory.redeemPull(seriesId);
        vm.prank(bob);
        factory.withdrawSettlement(seriesId);
        assertApproxEqAbs(susdm.convertToAssets(susdm.balanceOf(alice)), 2_000e6, 2);
        assertApproxEqAbs(susdm.convertToAssets(susdm.balanceOf(bob)), 4_000e6, 2);
    }

    function testExpireRefundsBoth() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18, type(uint256).max);
        vm.warp(block.timestamp + 365 days + 1);
        factory.expire(seriesId);
        vm.prank(alice);
        factory.redeemPull(seriesId);
        vm.prank(bob);
        factory.withdrawSettlement(seriesId);
        assertApproxEqAbs(susdm.convertToAssets(susdm.balanceOf(alice)), 2_000e6, 2);
        assertApproxEqAbs(susdm.convertToAssets(susdm.balanceOf(bob)), 4_000e6, 2);
    }

    function testGrowthIsProtocolIncomeNavUnchanged() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18, type(uint256).max);
        susdm.setRate(1.10e6);
        vm.prank(owner);
        resolver.voidMarket(marketId);
        factory.voidSeries(seriesId);
        uint256 aliceBefore = susdm.convertToAssets(susdm.balanceOf(alice));
        uint256 bobBefore = susdm.convertToAssets(susdm.balanceOf(bob));
        vm.prank(alice);
        factory.redeemPull(seriesId);
        vm.prank(bob);
        factory.withdrawSettlement(seriesId);
        assertApproxEqAbs(susdm.convertToAssets(susdm.balanceOf(alice)) - aliceBefore, 2_000e6, 5);
        assertApproxEqAbs(susdm.convertToAssets(susdm.balanceOf(bob)) - bobBefore, 4_000e6, 5);
        assertApproxEqAbs(susdm.convertToAssets(susdm.balanceOf(fee)), 600e6, 5);
    }

    function testOfficialTokenIsSettlementAsset() public {
        DeliveryLockbox box = new DeliveryLockbox(owner);
        vm.prank(owner);
        box.setFactory(address(factory));
        vm.prank(owner);
        factory.setLockbox(address(box));
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18, type(uint256).max);
        vm.prank(owner);
        resolver.resolve(marketId, uint64(block.chainid), address(varTok), 18, 1e18);
        factory.resolve(seriesId);
        varTok.mint(bob, 100e18);
        vm.startPrank(bob);
        varTok.approve(address(box), type(uint256).max);
        box.credit(seriesId, 100e18);
        vm.stopPrank();
        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.SETTLED));
        vm.prank(alice);
        factory.redeemPull(seriesId);
        assertEq(varTok.balanceOf(alice), 100e18);
    }

    function testOneXPrimaryFill() public {
        vm.startPrank(bob);
        bytes32 s1 = factory.createSeries(marketId, 10_000, 20e18);
        factory.depositAndMint(s1, 10e18, type(uint256).max);
        vm.stopPrank();
        vm.prank(alice);
        factory.buyFromSeries(s1, 10e18, type(uint256).max);
        assertEq(factory.vaultOf(marketId).escrowOf(s1), 200e6);
        assertEq(factory.vaultOf(marketId).collateralOf(s1), 200e6);
    }

    function testCloseUnsoldSeries() public {
        vm.startPrank(bob);
        factory.burnUnsoldAndWithdrawExcess(seriesId);
        factory.closeSeries(seriesId);
        vm.stopPrank();
        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.CLOSED));
        vm.prank(bob);
        factory.withdrawSettlement(seriesId);
        assertApproxEqAbs(susdm.balanceOf(bob), 4_000e12, 2);
    }

    function testPartialDeliveryDefaultReclaim() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18, type(uint256).max);
        vm.prank(owner);
        resolver.resolve(marketId, uint64(block.chainid), address(varTok), 18, 1e18);
        factory.resolve(seriesId);
        varTok.mint(bob, 40e18);
        vm.startPrank(bob);
        varTok.approve(address(factory), type(uint256).max);
        factory.deliver(seriesId, 40e18);
        vm.stopPrank();
        vm.warp(block.timestamp + 49 hours);
        factory.finalize(seriesId);
        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.DEFAULTED));
        vm.prank(bob);
        factory.reclaimPartialDelivery(seriesId);
        assertEq(varTok.balanceOf(bob), 40e18);
    }

    function testRejectSubDollarPrice() public {
        vm.prank(bob);
        vm.expectRevert(PreMarketFactory.Floor.selector);
        factory.createSeries(marketId, 20_000, 1e18 - 1);
    }

    function testTwoSellersSamePrice() public {
        address carol = address(0xCA);
        usdm.mint(carol, 1_000e6);
        vm.startPrank(carol);
        usdm.approve(address(factory), type(uint256).max);
        bytes32 other = factory.createSeries(marketId, 20_000, 20e18);
        factory.depositAndMint(other, 5e18, type(uint256).max);
        vm.stopPrank();
        assertTrue(other != seriesId);
        assertEq(ClaimSeriesToken(factory.seriesClaim(other)).symbol(), "hPreVarPts2x20");
    }

    function testRejectPlainUsdc() public {
        MockUsdm raw = new MockUsdm();
        vm.prank(owner);
        vm.expectRevert();
        factory.createMarket("nope", "X", address(raw));
    }

    function testNavDropTwoHoldersProRataNotFirstCome() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18, type(uint256).max);
        address claim = factory.seriesClaim(seriesId);
        address carol = address(0xCA);
        vm.prank(alice);
        ClaimSeriesToken(claim).transfer(carol, 50e18);

        vm.prank(owner);
        resolver.resolve(marketId, uint64(block.chainid), address(varTok), 18, 1e18);
        factory.resolve(seriesId);
        vm.warp(block.timestamp + 49 hours);
        factory.finalize(seriesId);
        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.DEFAULTED));

        susdm.setRate(500_000);

        vm.prank(alice);
        factory.redeemPull(seriesId);
        uint256 aliceGot = susdm.balanceOf(alice);
        vm.prank(carol);
        factory.redeemPull(seriesId);
        uint256 carolGot = susdm.balanceOf(carol);

        assertGt(carolGot, 0);
        assertApproxEqAbs(aliceGot, carolGot, 2);
        uint256 bag = aliceGot + carolGot;
        assertLt(aliceGot, bag);
        assertApproxEqAbs(aliceGot * 2, bag, 2);
    }

    function testRemoteOriginDeliverAndRedeem() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 50e18, type(uint256).max);

        PremarketOriginLock origin = new PremarketOriginLock(owner, owner, varTok);
        PremarketSameChainHub hub = new PremarketSameChainHub(owner);
        vm.startPrank(owner);
        hub.setEnds(address(origin), address(factory));
        origin.setMailbox(address(hub));
        factory.setLockbox(address(hub));
        // Official token is "on Arb" — HyperEVM deliver must fail.
        resolver.resolve(marketId, 42161, address(varTok), 18, 1e18);
        vm.stopPrank();
        factory.resolve(seriesId);

        varTok.mint(bob, 50e18);
        vm.startPrank(bob);
        varTok.approve(address(factory), 50e18);
        vm.expectRevert(PreMarketFactory.WrongChain.selector);
        factory.deliver(seriesId, 50e18);
        varTok.approve(address(origin), 50e18);
        origin.deliver(seriesId, 50e18, bob);
        vm.stopPrank();
        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.SETTLED));

        vm.prank(alice);
        factory.redeemPull(seriesId);
        assertEq(varTok.balanceOf(alice), 50e18);
        assertEq(origin.locked(seriesId), 0);
    }

    function testLzHubCreditAndRelease() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 20e18, type(uint256).max);

        MockLzEp epOrigin = new MockLzEp(30110);
        MockLzEp epHevm = new MockLzEp(30367);
        PremarketOriginLock origin = new PremarketOriginLock(owner, owner, varTok);
        PremarketLzHub src = new PremarketLzHub(address(epOrigin), owner, owner, true);
        PremarketLzHub dst = new PremarketLzHub(address(epHevm), owner, owner, false);
        vm.startPrank(owner);
        src.setLock(address(origin));
        dst.setFactory(address(factory));
        src.setPeer(30367, address(dst));
        dst.setPeer(30110, address(src));
        origin.setMailbox(address(src));
        factory.setLockbox(address(dst));
        resolver.resolve(marketId, 42161, address(varTok), 18, 1e18);
        vm.stopPrank();
        factory.resolve(seriesId);

        vm.deal(bob, 1 ether);
        varTok.mint(bob, 20e18);
        vm.startPrank(bob);
        varTok.approve(address(origin), 20e18);
        origin.deliver{value: 0.01 ether}(seriesId, 20e18, bob);
        vm.stopPrank();
        assertEq(epOrigin.lastRefund(), bob);

        bytes memory credit = abi.encode(uint8(1), seriesId, address(0), uint256(20e18));
        vm.prank(address(epHevm));
        dst.lzReceive(
            ILayerZeroEndpointV2.Origin(30110, bytes32(uint256(uint160(address(src)))), 1),
            bytes32(uint256(1)),
            credit,
            address(0),
            ""
        );
        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.SETTLED));

        vm.deal(alice, 1 ether);
        vm.prank(alice);
        factory.redeemPull{value: 0.01 ether}(seriesId);
        assertEq(ClaimSeriesToken(factory.seriesClaim(seriesId)).balanceOf(alice), 0);

        bytes memory rel = abi.encode(uint8(2), seriesId, alice, uint256(20e18));
        vm.prank(address(epOrigin));
        src.lzReceive(
            ILayerZeroEndpointV2.Origin(30367, bytes32(uint256(uint160(address(dst)))), 1),
            bytes32(uint256(2)),
            rel,
            address(0),
            ""
        );
        assertEq(varTok.balanceOf(alice), 20e18);
        assertEq(origin.locked(seriesId), 0);
    }
}

contract MockLzEp is ILayerZeroEndpointV2 {
    uint32 public eid;
    address public lastRefund;
    constructor(uint32 eid_) {
        eid = eid_;
    }
    function send(MessagingParams calldata p, address refund) external payable returns (MessagingReceipt memory r) {
        lastRefund = refund;
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
}
