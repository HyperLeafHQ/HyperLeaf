// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PaperOtcFactory} from "src/premarket/PaperOtcFactory.sol";

contract MockUsdm is ERC20 {
    constructor() ERC20("USDM", "USDM") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockSusdm is ERC20 {
    MockUsdm public immutable assetToken;
    uint256 public rate = 1e6;

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

    function previewWithdraw(uint256 assets) public view returns (uint256 shares) {
        shares = convertToShares(assets);
        if (convertToAssets(shares) < assets) shares += 1;
    }

    function deposit(uint256 assets, address to) external returns (uint256 shares) {
        shares = previewWithdraw(assets);
        require(assetToken.transferFrom(msg.sender, address(this), assets), "usdm");
        _mint(to, shares);
    }

    error UseCooldownFunctions();

    function withdraw(uint256, address, address) external pure returns (uint256) {
        revert UseCooldownFunctions();
    }

    function redeem(uint256, address, address) external pure returns (uint256) {
        revert UseCooldownFunctions();
    }

    function setRate(uint256 r) external {
        rate = r;
    }
}

contract MockPaper is ERC20 {
    constructor() ERC20("Paper", "PAPER") {}

    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract PaperOtcTest is Test {
    PaperOtcFactory factory;
    MockUsdm usdm;
    MockSusdm susdm;
    MockPaper paper;
    address owner = address(0xA11CE);
    address guardian = address(0x6A2D);
    address fee = address(0xFEE);
    address seller = address(0x5E11);
    address buyer = address(0xB0B);
    address stranger = address(0xBEEF);

    uint256 constant ONE = 1e18;
    uint256 constant PRICE = 1e6; // 1 USDM per PAPER

    function setUp() public {
        usdm = new MockUsdm();
        susdm = new MockSusdm(usdm);
        paper = new MockPaper();
        vm.prank(owner);
        factory = new PaperOtcFactory(owner, guardian, fee, address(usdm), address(susdm), address(paper));
        usdm.mint(seller, 1_000_000e6);
        usdm.mint(buyer, 1_000_000e6);
        paper.mint(seller, 1000e18);
        vm.prank(seller);
        usdm.approve(address(factory), type(uint256).max);
        vm.prank(buyer);
        usdm.approve(address(factory), type(uint256).max);
        vm.prank(seller);
        paper.approve(address(factory), type(uint256).max);
    }

    function _offer(uint256 collateral) internal returns (uint256 id) {
        vm.prank(seller);
        id = factory.createOffer(10 * ONE, PRICE, collateral, type(uint256).max);
    }

    function _match(uint256 collateral) internal returns (uint256 id) {
        id = _offer(collateral);
        vm.prank(buyer);
        factory.takeOffer(id, type(uint256).max);
    }

    function _enable() internal {
        vm.prank(owner);
        factory.proposeEnableTransfers();
        vm.prank(guardian);
        factory.confirmEnableTransfers(keccak256("paper-eoa-transfer"));
    }

    function testPaymentIsUsdmPerWholePaper() public view {
        assertEq(factory.paymentOf(10 * ONE, PRICE), 10e6);
    }

    function testRejectsCollateralOtherThanOneOrTwo() public {
        vm.prank(seller);
        vm.expectRevert(PaperOtcFactory.Collateral.selector);
        factory.createOffer(10 * ONE, PRICE, 15e6, type(uint256).max);
    }

    function testCancelOpenReturnsPrincipalShares() public {
        uint256 before = usdm.balanceOf(seller);
        uint256 id = _offer(10e6);
        vm.prank(seller);
        factory.cancelOffer(id);
        assertEq(usdm.balanceOf(seller), before - 10e6);
        assertGe(susdm.convertToAssets(susdm.balanceOf(seller)), 10e6);
        assertEq(susdm.balanceOf(fee), 0);
    }

    function testCancelShortfallReturnsShares() public {
        uint256 id = _offer(10e6);
        (,,,,,, uint256 shares,,,,,,) = _bag(id);
        susdm.setRate(0.5e6);
        vm.prank(seller);
        factory.cancelOffer(id);
        assertEq(usdm.balanceOf(seller), 1_000_000e6 - 10e6);
        assertEq(susdm.balanceOf(seller), shares);
        assertEq(susdm.balanceOf(fee), 0);
    }

    function testYieldOnExitGoesToFee() public {
        uint256 id = _offer(10e6);
        (,,,,,, uint256 shares,,,,,,) = _bag(id);
        susdm.setRate(2e6);
        vm.prank(seller);
        factory.cancelOffer(id);
        assertEq(usdm.balanceOf(seller), 1_000_000e6 - 10e6);
        assertEq(susdm.balanceOf(fee), shares / 2);
        assertEq(susdm.balanceOf(seller), shares / 2);
        assertGe(susdm.convertToAssets(susdm.balanceOf(seller)), 10e6);
    }

    function testMutualReturnsEachSide() public {
        uint256 id = _match(20e6);
        vm.prank(seller);
        factory.agreeMutual(id);
        (,,,,,,,,,, PaperOtcFactory.State st,,) = _bag(id);
        assertEq(uint256(st), uint256(PaperOtcFactory.State.Matched));
        vm.prank(buyer);
        factory.agreeMutual(id);
        (,,,,,,,,,, st,,) = _bag(id);
        assertEq(uint256(st), uint256(PaperOtcFactory.State.Mutual));
        assertEq(usdm.balanceOf(seller), 1_000_000e6 - 20e6);
        assertEq(usdm.balanceOf(buyer), 1_000_000e6 - 10e6);
        assertGe(susdm.convertToAssets(susdm.balanceOf(seller)), 20e6);
        assertGe(susdm.convertToAssets(susdm.balanceOf(buyer)), 10e6);
    }

    function testSellerWalkGivesBuyerBothBags() public {
        uint256 sellerBefore = usdm.balanceOf(seller);
        uint256 id = _match(20e6);
        vm.prank(seller);
        factory.sellerWalk(id);
        assertEq(usdm.balanceOf(seller), sellerBefore - 20e6);
        assertEq(usdm.balanceOf(buyer), 1_000_000e6 - 10e6);
        assertGe(susdm.convertToAssets(susdm.balanceOf(buyer)), 30e6);
        assertEq(susdm.balanceOf(seller), 0);
    }

    function testTimeoutIsDualRefundWithoutPenalty() public {
        uint256 id = _match(10e6);
        vm.expectRevert(PaperOtcFactory.Window.selector);
        factory.timeoutCash(id);
        vm.warp(block.timestamp + 180 days);
        vm.prank(stranger);
        factory.timeoutCash(id);
        assertEq(usdm.balanceOf(seller), 1_000_000e6 - 10e6);
        assertEq(usdm.balanceOf(buyer), 1_000_000e6 - 10e6);
        assertGe(susdm.convertToAssets(susdm.balanceOf(seller)), 10e6);
        assertGe(susdm.convertToAssets(susdm.balanceOf(buyer)), 10e6);
    }

    function testDeliverRequiresEnableAndExactBalance() public {
        uint256 id = _match(10e6);
        vm.prank(seller);
        vm.expectRevert(PaperOtcFactory.Transfers.selector);
        factory.deliverPaper(id);
        _enable();
        vm.prank(buyer);
        vm.expectRevert(PaperOtcFactory.NotSeller.selector);
        factory.deliverPaper(id);
        vm.prank(seller);
        factory.deliverPaper(id);
        assertEq(paper.balanceOf(address(factory)), 10e18);
        vm.prank(seller);
        factory.settlePhysical(id);
        assertEq(paper.balanceOf(buyer), 10e18);
        assertGe(susdm.convertToAssets(susdm.balanceOf(seller)), 20e6);
        assertEq(usdm.balanceOf(seller), 1_000_000e6 - 10e6);
        assertEq(paper.balanceOf(address(factory)), 0);
    }

    function testBuyerCanSettlePhysical() public {
        uint256 id = _match(10e6);
        _enable();
        vm.prank(seller);
        factory.deliverPaper(id);
        vm.prank(buyer);
        factory.settlePhysical(id);
        assertEq(paper.balanceOf(buyer), 10e18);
    }

    function testStrangerCannotSettle() public {
        uint256 id = _match(10e6);
        _enable();
        vm.prank(seller);
        factory.deliverPaper(id);
        vm.prank(stranger);
        vm.expectRevert(PaperOtcFactory.NotParty.selector);
        factory.settlePhysical(id);
    }

    function testDefaultAfter48hEnabledTimeGivesBuyerBoth() public {
        uint256 id = _match(20e6);
        _enable();
        vm.warp(block.timestamp + 48 hours);
        vm.prank(stranger);
        factory.finalizeSellerDefault(id);
        assertEq(paper.balanceOf(buyer), 0);
        assertEq(paper.balanceOf(address(factory)), 0);
        assertEq(usdm.balanceOf(buyer), 1_000_000e6 - 10e6);
        assertGe(susdm.convertToAssets(susdm.balanceOf(buyer)), 30e6);
    }

    function testDisablePausesDeliveryClock() public {
        uint256 id = _match(10e6);
        _enable();
        vm.warp(block.timestamp + 40 hours);
        vm.prank(guardian);
        factory.disableTransfers();
        vm.warp(block.timestamp + 30 days);
        vm.expectRevert(PaperOtcFactory.Transfers.selector);
        factory.finalizeSellerDefault(id);
        vm.prank(owner);
        factory.proposeEnableTransfers();
        vm.prank(guardian);
        factory.confirmEnableTransfers(keccak256("again"));
        vm.expectRevert(PaperOtcFactory.Window.selector);
        factory.finalizeSellerDefault(id);
        vm.warp(block.timestamp + 8 hours);
        factory.finalizeSellerDefault(id);
    }

    function testClockDoesNotStartUntilEnabled() public {
        uint256 id = _match(10e6);
        vm.warp(block.timestamp + 10 days);
        _enable();
        vm.expectRevert(PaperOtcFactory.Window.selector);
        factory.finalizeSellerDefault(id);
        vm.warp(block.timestamp + 48 hours);
        factory.finalizeSellerDefault(id);
    }

    function testOwnerCannotEnableAlone() public {
        vm.prank(owner);
        factory.proposeEnableTransfers();
        vm.prank(owner);
        vm.expectRevert(PaperOtcFactory.NotGuardian.selector);
        factory.confirmEnableTransfers(keccak256("x"));
        assertFalse(factory.paperTransfersEnabled());
    }

    function testConfirmRequiresProofRef() public {
        vm.prank(owner);
        factory.proposeEnableTransfers();
        vm.prank(guardian);
        vm.expectRevert(PaperOtcFactory.Proof.selector);
        factory.confirmEnableTransfers(bytes32(0));
    }

    function testGuardianCannotEnableAlone() public {
        vm.prank(guardian);
        vm.expectRevert(PaperOtcFactory.Transfers.selector);
        factory.confirmEnableTransfers(keccak256("x"));
    }

    function testPauseBlocksNewOffersNotExits() public {
        uint256 id = _match(10e6);
        vm.prank(guardian);
        factory.pause();
        vm.prank(seller);
        vm.expectRevert(PaperOtcFactory.OffersPaused.selector);
        factory.createOffer(ONE, PRICE, 1e6, type(uint256).max);
        vm.prank(seller);
        factory.sellerWalk(id);
    }

    function testShortfallOnMatchedExitDoesNotTopUp() public {
        uint256 id = _match(10e6);
        (,,,,,, uint256 sellerShares, uint256 buyerShares,,,,,) = _bag(id);
        susdm.setRate(0.4e6);
        vm.prank(seller);
        factory.sellerWalk(id);
        assertEq(susdm.balanceOf(buyer), sellerShares + buyerShares);
        assertEq(usdm.balanceOf(buyer), 1_000_000e6 - 10e6);
        assertEq(usdm.balanceOf(address(factory)), 0);
    }

    function testCashExitStillWorksWhileTransfersOff() public {
        uint256 id = _match(10e6);
        vm.warp(block.timestamp + 180 days);
        factory.timeoutCash(id);
        assertGe(susdm.convertToAssets(susdm.balanceOf(seller)), 10e6);
        assertEq(usdm.balanceOf(seller), 1_000_000e6 - 10e6);
    }

    function testDeliverThenNoWalk() public {
        uint256 id = _match(10e6);
        _enable();
        vm.prank(seller);
        factory.deliverPaper(id);
        vm.prank(seller);
        vm.expectRevert(PaperOtcFactory.BadState.selector);
        factory.sellerWalk(id);
    }

    function testPauseBlocksTake() public {
        uint256 id = _offer(10e6);
        vm.prank(owner);
        factory.pause();
        vm.prank(buyer);
        vm.expectRevert(PaperOtcFactory.OffersPaused.selector);
        factory.takeOffer(id, type(uint256).max);
    }

    function testCancelMatchedReverts() public {
        uint256 id = _match(10e6);
        vm.prank(seller);
        vm.expectRevert(PaperOtcFactory.BadState.selector);
        factory.cancelOffer(id);
    }

    function testTimeoutCannotEraseDefaultAfterEnable() public {
        uint256 id = _match(20e6);
        _enable();
        vm.warp(block.timestamp + 180 days);
        vm.expectRevert(PaperOtcFactory.Transfers.selector);
        factory.timeoutCash(id);
        factory.finalizeSellerDefault(id);
        assertGe(susdm.convertToAssets(susdm.balanceOf(buyer)), 30e6);
    }

    function testFeeRecipientDelay() public {
        vm.prank(owner);
        factory.proposeFeeRecipient(stranger);
        vm.warp(block.timestamp + 2 days - 1);
        vm.prank(owner);
        vm.expectRevert(PaperOtcFactory.Window.selector);
        factory.acceptFeeRecipient();
        vm.warp(block.timestamp + 1);
        vm.prank(owner);
        factory.acceptFeeRecipient();
        assertEq(factory.feeRecipient(), stranger);
    }

    function testTwoTimesCollateralPhysicalPaysSellerShares() public {
        uint256 id = _match(20e6);
        _enable();
        vm.prank(seller);
        factory.deliverPaper(id);
        vm.prank(buyer);
        factory.settlePhysical(id);
        assertEq(paper.balanceOf(buyer), 10e18);
        assertGe(susdm.convertToAssets(susdm.balanceOf(seller)), 30e6);
        assertEq(susdm.balanceOf(buyer), 0);
    }

    function testCashWindowDiesOnceDeliveryCycleStarts() public {
        uint256 id = _match(10e6);
        _enable();
        vm.prank(guardian);
        factory.disableTransfers();
        vm.warp(block.timestamp + 180 days);
        assertTrue(factory.deliveryCycleStarted(id));
        vm.expectRevert(PaperOtcFactory.Transfers.selector);
        factory.timeoutCash(id);
    }

    function testMatchWhileEnabledHasNoCashWindow() public {
        _enable();
        uint256 id = _match(10e6);
        assertTrue(factory.deliveryCycleStarted(id));
        vm.warp(block.timestamp + 180 days);
        vm.prank(guardian);
        factory.disableTransfers();
        vm.expectRevert(PaperOtcFactory.Transfers.selector);
        factory.timeoutCash(id);
    }

    function testBagsStayIsolatedWhenOneIsShort() public {
        uint256 a = _offer(10e6);
        uint256 b = _offer(10e6);
        susdm.setRate(0.5e6);
        vm.prank(seller);
        factory.cancelOffer(a);
        susdm.setRate(1e6);
        vm.prank(seller);
        factory.cancelOffer(b);
        assertEq(usdm.balanceOf(seller), 1_000_000e6 - 20e6);
        assertEq(susdm.balanceOf(address(factory)), 0);
        assertGt(susdm.balanceOf(seller), 0);
    }

    function _bag(uint256 id)
        internal
        view
        returns (
            address seller_,
            address buyer_,
            uint256 paperAmount,
            uint256 price,
            uint256 sellerPrincipal,
            uint256 buyerPrincipal,
            uint256 sellerShares,
            uint256 buyerShares,
            uint64 matchedAt,
            uint64 deliveryStart,
            PaperOtcFactory.State state,
            bool,
            bool
        )
    {
        return factory.offers(id);
    }
}
