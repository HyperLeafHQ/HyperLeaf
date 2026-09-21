// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {NativeOtcFactory} from "src/premarket/NativeOtcFactory.sol";
import {NativeDeliveryResolver} from "src/premarket/NativeDeliveryResolver.sol";

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

    function deposit(uint256 assets, address to) external returns (uint256 shares) {
        shares = convertToShares(assets);
        if (convertToAssets(shares) < assets) shares += 1;
        require(assetToken.transferFrom(msg.sender, address(this), assets), "usdm");
        _mint(to, shares);
    }
}

contract NativeOtcTest is Test {
    NativeOtcFactory factory;
    NativeDeliveryResolver resolver;
    MockUsdm usdm;
    MockSusdm susdm;
    address owner = address(0xA11CE);
    address fee = address(0xFEE);
    address seller = address(0x5E11);
    address buyer = address(0xB0B);
    bytes dest = bytes("5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY");

    function setUp() public {
        usdm = new MockUsdm();
        susdm = new MockSusdm(usdm);
        vm.prank(owner);
        resolver = new NativeDeliveryResolver(owner);
        vm.prank(owner);
        factory = new NativeOtcFactory(owner, address(resolver), fee, address(susdm));
        usdm.mint(seller, 1_000_000e6);
        usdm.mint(buyer, 1_000_000e6);
        vm.prank(seller);
        usdm.approve(address(factory), type(uint256).max);
        vm.prank(buyer);
        usdm.approve(address(factory), type(uint256).max);
    }

    function _offer() internal returns (bytes32 id) {
        vm.prank(seller);
        id = factory.createOffer(100e12, 2_500e6, 2_500e6, 7 days, type(uint256).max);
    }

    function testCreateThenCancel() public {
        bytes32 id = _offer();
        (address s,,,,,,,,, NativeOtcFactory.State st,) = factory.offers(id);
        assertEq(s, seller);
        assertEq(uint256(st), uint256(NativeOtcFactory.State.OPEN));
        vm.prank(seller);
        factory.cancelOffer(id);
        (,,,,,,,,, st,) = factory.offers(id);
        assertEq(uint256(st), uint256(NativeOtcFactory.State.CANCELLED));
        assertGt(susdm.balanceOf(seller), 0);
    }

    function testTakeSettlePaysSeller() public {
        bytes32 id = _offer();
        vm.prank(buyer);
        factory.takeOffer(id, dest, type(uint256).max);
        vm.prank(owner);
        resolver.attest(id, keccak256("qtc-tx"), keccak256(dest), 100e12);
        factory.settle(id);
        (,,,,,,,,, NativeOtcFactory.State st,) = factory.offers(id);
        assertEq(uint256(st), uint256(NativeOtcFactory.State.SETTLED));
        assertGt(susdm.balanceOf(seller), 0);
        assertEq(susdm.balanceOf(buyer), 0);
    }

    function testWrongDestCannotSettle() public {
        bytes32 id = _offer();
        vm.prank(buyer);
        factory.takeOffer(id, dest, type(uint256).max);
        vm.prank(owner);
        resolver.attest(id, keccak256("qtc-tx"), keccak256("other"), 100e12);
        vm.expectRevert(NativeOtcFactory.Dest.selector);
        factory.settle(id);
    }

    function testShortfallCannotSettle() public {
        bytes32 id = _offer();
        vm.prank(buyer);
        factory.takeOffer(id, dest, type(uint256).max);
        vm.prank(owner);
        resolver.attest(id, keccak256("qtc-tx"), keccak256(dest), 99e12);
        vm.expectRevert(NativeOtcFactory.Amount.selector);
        factory.settle(id);
    }

    function testDefaultPaysBuyerAfterWindow() public {
        bytes32 id = _offer();
        vm.prank(buyer);
        factory.takeOffer(id, dest, type(uint256).max);
        vm.warp(block.timestamp + factory.DELIVERY_WINDOW() + 1);
        factory.finalize(id);
        (,,,,,,,,, NativeOtcFactory.State st,) = factory.offers(id);
        assertEq(uint256(st), uint256(NativeOtcFactory.State.DEFAULTED));
        assertGt(susdm.balanceOf(buyer), 0);
        assertEq(susdm.balanceOf(seller), 0);
    }

    function testFinalizeBeforeWindowReverts() public {
        bytes32 id = _offer();
        vm.prank(buyer);
        factory.takeOffer(id, dest, type(uint256).max);
        vm.expectRevert(NativeOtcFactory.Window.selector);
        factory.finalize(id);
    }

    function testSellerCannotTakeOwnOffer() public {
        bytes32 id = _offer();
        vm.prank(seller);
        vm.expectRevert(NativeOtcFactory.Self.selector);
        factory.takeOffer(id, dest, type(uint256).max);
    }

    function testAttestCanOverwrite() public {
        bytes32 id = _offer();
        vm.prank(owner);
        resolver.attest(id, keccak256("qtc-tx"), keccak256("other"), 50e12);
        vm.prank(owner);
        resolver.attest(id, keccak256("qtc-tx-2"), keccak256(dest), 100e12);
        (bytes32 txHash, bytes32 destHash, uint256 atoms,, bool ok) = resolver.attestation(id);
        assertTrue(ok);
        assertEq(txHash, keccak256("qtc-tx-2"));
        assertEq(destHash, keccak256(dest));
        assertEq(atoms, 100e12);
    }

    function testWrongAttestThenCorrectThenSettle() public {
        bytes32 id = _offer();
        vm.prank(buyer);
        factory.takeOffer(id, dest, type(uint256).max);
        vm.prank(owner);
        resolver.attest(id, keccak256("bad"), keccak256("other"), 100e12);
        vm.expectRevert(NativeOtcFactory.Dest.selector);
        factory.settle(id);
        vm.prank(owner);
        resolver.attest(id, keccak256("qtc-tx"), keccak256(dest), 100e12);
        factory.settle(id);
        (,,,,,,,,, NativeOtcFactory.State st,) = factory.offers(id);
        assertEq(uint256(st), uint256(NativeOtcFactory.State.SETTLED));
    }

    function testShortfallThenCorrectThenSettle() public {
        bytes32 id = _offer();
        vm.prank(buyer);
        factory.takeOffer(id, dest, type(uint256).max);
        vm.prank(owner);
        resolver.attest(id, keccak256("qtc-tx"), keccak256(dest), 99e12);
        vm.expectRevert(NativeOtcFactory.Amount.selector);
        factory.settle(id);
        vm.prank(owner);
        resolver.attest(id, keccak256("qtc-tx"), keccak256(dest), 100e12);
        factory.settle(id);
        (,,,,,,,,, NativeOtcFactory.State st,) = factory.offers(id);
        assertEq(uint256(st), uint256(NativeOtcFactory.State.SETTLED));
    }

    function testSettleAfterWindowRevertsEvenIfAttested() public {
        bytes32 id = _offer();
        vm.prank(buyer);
        factory.takeOffer(id, dest, type(uint256).max);
        vm.prank(owner);
        resolver.attest(id, keccak256("qtc-tx"), keccak256(dest), 100e12);
        vm.warp(block.timestamp + factory.DELIVERY_WINDOW() + 1);
        vm.expectRevert(NativeOtcFactory.Window.selector);
        factory.settle(id);
    }

    function testLateAttestCannotSettle() public {
        bytes32 id = _offer();
        vm.prank(buyer);
        factory.takeOffer(id, dest, type(uint256).max);
        vm.warp(block.timestamp + factory.DELIVERY_WINDOW() + 1);
        vm.prank(owner);
        resolver.attest(id, keccak256("late"), keccak256(dest), 100e12);
        vm.expectRevert(NativeOtcFactory.Window.selector);
        factory.settle(id);
        vm.expectRevert(NativeOtcFactory.BadState.selector);
        factory.finalize(id);
        vm.prank(owner);
        resolver.revoke(id);
        factory.finalize(id);
        (,,,,,,,,, NativeOtcFactory.State st,) = factory.offers(id);
        assertEq(uint256(st), uint256(NativeOtcFactory.State.DEFAULTED));
    }

    function testExactWindowSettleStillOk() public {
        bytes32 id = _offer();
        vm.prank(buyer);
        factory.takeOffer(id, dest, type(uint256).max);
        vm.prank(owner);
        resolver.attest(id, keccak256("qtc-tx"), keccak256(dest), 100e12);
        vm.warp(block.timestamp + factory.DELIVERY_WINDOW());
        factory.settle(id);
        (,,,,,,,,, NativeOtcFactory.State st,) = factory.offers(id);
        assertEq(uint256(st), uint256(NativeOtcFactory.State.SETTLED));
    }

    function testRevokeWithoutAttestReverts() public {
        bytes32 id = _offer();
        vm.prank(owner);
        vm.expectRevert(NativeDeliveryResolver.NotAttested.selector);
        resolver.revoke(id);
    }
}
