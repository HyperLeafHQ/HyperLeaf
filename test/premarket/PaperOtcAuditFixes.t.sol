// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PaperOtcFactory} from "src/premarket/PaperOtcFactory.sol";
import {PremarketAddresses} from "src/premarket/PremarketAddresses.sol";
import {MockUsdm, MockSusdm, MockPaper} from "./PaperOtc.t.sol";

/// @notice MockSusdm clone whose previewWithdraw can be made to revert, modelling a future
///         Monetrix upgrade that disables the preview path (docs/PAPER_OTC.md, Monetrix trust surface).
contract PreviewRevertSusdm is ERC20 {
    MockUsdm public immutable assetToken;
    uint256 public rate = 1e6;
    bool public revertPreview;
    bool public revertConvert;

    error UseCooldownFunctions();

    constructor(MockUsdm a) ERC20("sUSDM", "sUSDM") {
        assetToken = a;
    }

    function decimals() public pure override returns (uint8) {
        return 12;
    }

    function asset() external view returns (address) {
        return address(assetToken);
    }

    function setRate(uint256 r) external {
        rate = r;
    }

    function setRevertPreview() external {
        revertPreview = true;
    }

    function setRevertConvert() external {
        revertConvert = true;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (revertConvert) revert UseCooldownFunctions();
        return (shares * rate) / 1e12;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return (assets * 1e12) / rate;
    }

    function previewWithdraw(uint256 assets) public view returns (uint256 shares) {
        if (revertPreview) revert UseCooldownFunctions();
        shares = convertToShares(assets);
        if (convertToAssets(shares) < assets) shares += 1;
    }

    function deposit(uint256 assets, address to) external returns (uint256 shares) {
        shares = convertToShares(assets);
        if (convertToAssets(shares) < assets) shares += 1;
        require(assetToken.transferFrom(msg.sender, address(this), assets), "usdm");
        _mint(to, shares);
    }
}

/// @notice Audit-fix characterization tests for PR #115. They pin CURRENT behavior (including
///         behavior flagged as open design decisions in docs/PAPER_OTC.md) so any future change
///         is a deliberate diff. No contract logic is changed by this file.
contract PaperOtcAuditFixesTest is Test {
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
    uint256 constant PRICE = 1e6;

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
        factory.confirmEnableTransfers(keccak256("proof"));
    }

    /// @notice Characterization: a covered bag + reverting previewWithdraw takes the catch arm:
    ///         the party receives the WHOLE bag (principal + all yield), feeRecipient gets nothing.
    ///         Matches docs/PAPER_OTC.md "Monetrix trust surface": user-favorable, protocol revenue zero.
    function testAudit_PreviewRevertCatchArmReturnsWholeBagZeroFee() public {
        PreviewRevertSusdm evil = new PreviewRevertSusdm(usdm);
        vm.prank(owner);
        PaperOtcFactory f = new PaperOtcFactory(owner, guardian, fee, address(usdm), address(evil), address(paper));
        vm.prank(seller);
        usdm.approve(address(f), type(uint256).max);
        vm.prank(seller);
        uint256 id = f.createOffer(10 * ONE, PRICE, 10e6, type(uint256).max);
        (,,,,,, uint256 shares,,,,,,) = f.offers(id);
        evil.setRate(2e6); // bag now worth 20e6 against a 10e6 principal: yield exists
        evil.setRevertPreview(); // Monetrix upgrade disables the preview path
        vm.prank(seller);
        f.cancelOffer(id);
        assertEq(evil.balanceOf(seller), shares, "party receives whole bag");
        assertEq(evil.balanceOf(fee), 0, "fee scrape silently stops");
        assertEq(evil.convertToAssets(shares), 20e6, "party got principal + all yield");
    }

    function testAudit_ConvertRevertCancelReturnsWholeBag() public {
        PreviewRevertSusdm evil = new PreviewRevertSusdm(usdm);
        vm.prank(owner);
        PaperOtcFactory f = new PaperOtcFactory(owner, guardian, fee, address(usdm), address(evil), address(paper));
        vm.prank(seller);
        usdm.approve(address(f), type(uint256).max);
        vm.prank(seller);
        uint256 id = f.createOffer(10 * ONE, PRICE, 10e6, type(uint256).max);
        (,,,,,, uint256 shares,,,,,,) = f.offers(id);
        evil.setRevertConvert();
        vm.prank(seller);
        f.cancelOffer(id);
        (,,,,,,,,,, PaperOtcFactory.State st,,) = f.offers(id);
        assertEq(uint256(st), uint256(PaperOtcFactory.State.Cancelled));
        assertEq(evil.balanceOf(seller), shares);
        assertEq(evil.balanceOf(fee), 0);
    }

    function testAudit_ConvertRevertWalkReturnsBothBags() public {
        PreviewRevertSusdm evil = new PreviewRevertSusdm(usdm);
        vm.prank(owner);
        PaperOtcFactory f = new PaperOtcFactory(owner, guardian, fee, address(usdm), address(evil), address(paper));
        vm.prank(seller);
        usdm.approve(address(f), type(uint256).max);
        vm.prank(buyer);
        usdm.approve(address(f), type(uint256).max);
        vm.prank(seller);
        uint256 id = f.createOffer(10 * ONE, PRICE, 20e6, type(uint256).max);
        vm.prank(buyer);
        f.takeOffer(id, type(uint256).max);
        (,,,,,, uint256 sellerShares, uint256 buyerShares,,,,,) = f.offers(id);
        evil.setRevertConvert();
        vm.prank(seller);
        f.sellerWalk(id);
        (,,,,,,,,,, PaperOtcFactory.State st,,) = f.offers(id);
        assertEq(uint256(st), uint256(PaperOtcFactory.State.Walked));
        assertEq(evil.balanceOf(buyer), sellerShares + buyerShares);
        assertEq(evil.balanceOf(seller), 0);
        assertEq(evil.balanceOf(fee), 0);
    }

    /// @notice Once the delivery cycle has started, a later disable does not reopen the 180-day refund.
    function testAudit_DeliveryCycleKeepsCashWindowClosed() public {
        uint256 id = _match(20e6);
        _enable();
        vm.warp(block.timestamp + 47 hours);
        vm.prank(guardian);
        factory.disableTransfers();
        vm.warp(block.timestamp + 200 days);
        vm.expectRevert(PaperOtcFactory.Transfers.selector);
        factory.finalizeSellerDefault(id);
        vm.expectRevert(PaperOtcFactory.Transfers.selector);
        factory.timeoutCash(id);
        assertTrue(factory.deliveryCycleStarted(id));
        assertEq(susdm.balanceOf(seller), 0);
        assertEq(susdm.balanceOf(buyer), 0);
    }

    /// @notice On chain 999 the constructor rejects any USDM/sUSDM/PAPER other than the Monetrix pins.
    function testAudit_ChainidPinRejectsForeignTokens() public {
        vm.chainId(PremarketAddresses.HYPEREVM);
        address USDM = PremarketAddresses.USDM;
        address SUSDM = PremarketAddresses.SUSDM;
        address PAPER = factory.PAPER();
        vm.expectRevert(PaperOtcFactory.Zero.selector);
        new PaperOtcFactory(owner, guardian, fee, address(usdm), SUSDM, PAPER); // foreign USDM
        vm.expectRevert(PaperOtcFactory.Zero.selector);
        new PaperOtcFactory(owner, guardian, fee, USDM, address(susdm), PAPER); // foreign sUSDM
        vm.expectRevert(PaperOtcFactory.Zero.selector);
        new PaperOtcFactory(owner, guardian, fee, USDM, SUSDM, address(paper)); // foreign PAPER
    }

    /// @notice Characterization: re-proposing a fee recipient overwrites the pending one AND resets
    ///         the 2-day ETA. The owner can postpone a change indefinitely by re-proposing.
    function testAudit_FeeReproposalResetsEta() public {
        vm.prank(owner);
        factory.proposeFeeRecipient(stranger);
        uint64 eta1 = factory.feeEta();
        vm.warp(eta1 - 1);
        vm.prank(owner);
        factory.proposeFeeRecipient(buyer); // overwrite one second before eta1
        uint64 eta2 = factory.feeEta();
        assertEq(eta2, eta1 - 1 + 2 days, "eta fully reset by re-proposal");
        vm.warp(eta1);
        vm.prank(owner);
        vm.expectRevert(PaperOtcFactory.Window.selector); // old eta would already have passed
        factory.acceptFeeRecipient();
        vm.warp(eta2);
        vm.prank(owner);
        factory.acceptFeeRecipient();
        assertEq(factory.feeRecipient(), buyer);
        assertEq(factory.pendingFeeRecipient(), address(0));
    }
}
