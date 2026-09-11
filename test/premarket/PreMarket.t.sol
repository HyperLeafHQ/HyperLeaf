// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PreMarketFactory} from "src/premarket/PreMarketFactory.sol";
import {MultisigResolver} from "src/premarket/MultisigResolver.sol";
import {ClaimSeriesToken} from "src/premarket/ClaimSeriesToken.sol";
import {DeliveryLockbox} from "src/premarket/DeliveryLockbox.sol";

contract MockUsd is ERC20 {
    constructor() ERC20("USDL", "USDL") {}
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    function mint(address to, uint256 a) external {
        _mint(to, a);
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
    MockUsd usd;
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
        usd = new MockUsd();
        varTok = new MockVar();
        vm.prank(owner);
        marketId = factory.createMarket("Variational points", "Var", address(usd));
        usd.mint(bob, 10_000e6);
        usd.mint(alice, 10_000e6);
        vm.startPrank(bob);
        usd.approve(address(factory), type(uint256).max);
        seriesId = factory.createSeries(marketId, 20_000, 20e18);
        factory.depositAndMint(seriesId, 100e18);
        vm.stopPrank();
        vm.prank(alice);
        usd.approve(address(factory), type(uint256).max);
    }

    function testTickerAndFloor() public view {
        address tok = factory.seriesClaim(seriesId);
        assertEq(ClaimSeriesToken(tok).symbol(), "hPerVarPts-20-2X");
        assertEq(factory.seriesUnit(seriesId), 40e6);
        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.OPEN));
    }

    function testOneXAndRejectThreeX() public {
        vm.prank(bob);
        bytes32 s1 = factory.createSeries(marketId, 10_000, 20e18);
        assertEq(factory.seriesUnit(s1), 20e6);
        assertEq(ClaimSeriesToken(factory.seriesClaim(s1)).symbol(), "hPerVarPts-20-1X");
        vm.prank(bob);
        vm.expectRevert(PreMarketFactory.BadTier.selector);
        factory.createSeries(marketId, 30_000, 20e18);
    }

    function testAnyDealPrice() public {
        vm.prank(bob);
        bytes32 odd = factory.createSeries(marketId, 20_000, 17e18);
        assertEq(ClaimSeriesToken(factory.seriesClaim(odd)).symbol(), "hPerVarPts-17-2X");
        assertEq(factory.seriesUnit(odd), 34e6);
    }

    function testPrimaryFillThenDeliver() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18);
        address tok = factory.seriesClaim(seriesId);
        assertEq(ClaimSeriesToken(tok).balanceOf(alice), 100e18);
        assertEq(factory.vaultOf(marketId).escrowOf(seriesId), 2_000e6);

        vm.prank(owner);
        resolver.resolve(marketId, address(varTok), 1e18);
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

        vm.prank(bob);
        factory.withdrawSettlement(seriesId);
        assertEq(usd.balanceOf(bob), 10_000e6 - 4_000e6 + 4_000e6 + 2_000e6);
    }

    function testDefaultPaysHoldersNotSellerHeld() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18);
        address claim = factory.seriesClaim(seriesId);
        vm.prank(alice);
        ClaimSeriesToken(claim).transfer(bob, 40e18);

        vm.prank(owner);
        resolver.resolve(marketId, address(varTok), 1e18);
        factory.resolve(seriesId);
        vm.warp(block.timestamp + 49 hours);
        factory.finalize(seriesId);

        assertEq(uint256(factory.seriesState(seriesId)), uint256(PreMarketFactory.State.DEFAULTED));
        assertEq(factory.seriesFinalSold(seriesId), 60e18);
        assertEq(ClaimSeriesToken(factory.seriesClaim(seriesId)).balanceOf(bob), 0);

        uint256 aliceUsd = usd.balanceOf(alice);
        vm.prank(alice);
        factory.redeemPull(seriesId);
        assertEq(usd.balanceOf(alice) - aliceUsd, 2_000e6 + 2_400e6);
    }

    function testVoidRefundsBoth() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18);
        vm.prank(owner);
        resolver.voidMarket(marketId);
        factory.voidSeries(seriesId);
        vm.prank(alice);
        factory.redeemPull(seriesId);
        assertEq(usd.balanceOf(alice), 10_000e6);
        vm.prank(bob);
        factory.withdrawSettlement(seriesId);
        assertEq(usd.balanceOf(bob), 10_000e6);
    }

    function testExpireRefundsBoth() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18);
        vm.warp(block.timestamp + 365 days + 1);
        factory.expire(seriesId);
        vm.prank(alice);
        factory.redeemPull(seriesId);
        vm.prank(bob);
        factory.withdrawSettlement(seriesId);
        assertEq(usd.balanceOf(alice), 10_000e6);
        assertEq(usd.balanceOf(bob), 10_000e6);
    }

    function testHarvestInterestToFee() public {
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18);
        usd.mint(address(factory.vaultOf(marketId)), 50e6);
        factory.harvest(seriesId);
        assertEq(usd.balanceOf(fee), 50e6);
    }

    function testOfficialTokenIsSettlementAsset() public {
        DeliveryLockbox box = new DeliveryLockbox(owner);
        vm.prank(owner);
        box.setFactory(address(factory));
        vm.prank(owner);
        factory.setLockbox(address(box));
        vm.prank(alice);
        factory.buyFromSeries(seriesId, 100e18);
        vm.prank(owner);
        resolver.resolve(marketId, address(varTok), 1e18);
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
}
