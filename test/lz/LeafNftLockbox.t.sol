// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafNftLockbox} from "src/lz/LeafNftLockbox.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {LeafVePolicy} from "src/lz/LeafVePolicy.sol";
import {IVeNft} from "src/lz/IVeNft.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";
import {MockVeNft} from "test/mocks/MockVeNft.sol";

contract MockNftEndpoint is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30184;
    }
    function send(MessagingParams calldata, address) external payable returns (MessagingReceipt memory r) {
        r.guid = bytes32(uint256(1));
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

contract MockBribe is ERC20 {
    constructor() ERC20("BRIBE", "BRIBE") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract LeafNftLockboxTest is PegReady {
    MockNftEndpoint ep;
    MockVeNft ve;
    MockBribe bribe;
    LeafNftLockbox box;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address user = address(0xCAFE);

    function setUp() public {
        ep = new MockNftEndpoint();
        ve = new MockVeNft();
        bribe = new MockBribe();
        vm.startPrank(owner);
        box = new LeafNftLockbox(address(ve), address(ep), owner, guardian, feeTo, 1_000e18);
        box.setConverter(address(0xC0));
        box.setPeer(30367, address(1));
        vm.stopPrank();
        _openSrc(box, owner, 1_000e18);
        vm.deal(user, 1 ether);
    }

    function _wrap(uint256 id, uint256 amt) internal {
        ve.mint(user, id, int128(uint128(amt)), true, 0);
        vm.startPrank(user);
        ve.approve(address(box), id);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), id, user);
        vm.stopPrank();
    }

    function testCatalogNotADeployBatch() public {
        AssetCatalog.Listing memory a = AssetCatalog.get("hveaero");
        assertEq(a.innerMainnet, LeafVePolicy.VE);
        assertEq(uint8(a.kind), uint8(AssetCatalog.Kind.Closed));
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._requireBatch("hveaero", 4);
    }

    function _requireBatch(string calldata id, uint8 batch) external pure {
        MainnetBatches.requireBatch(id, batch);
    }

    function testPermanentMintsPrincipal() public {
        _wrap(7, 100e18);
        assertEq(ve.ownerOf(7), address(box));
        assertEq(box.totalLocked(), 100e18);
        assertEq(box.principalOf(7), 100e18);
        assertEq(box.heldCount(), 1);
    }

    function testRejectsTimeLocked() public {
        ve.mint(user, 8, int128(uint128(100e18)), false, block.timestamp + 365 days);
        vm.startPrank(user);
        ve.approve(address(box), 8);
        vm.expectRevert(LeafNftLockbox.BadNft.selector);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 8, user);
        vm.stopPrank();
    }

    function testRejectsManaged() public {
        ve.mint(user, 9, int128(uint128(50e18)), true, 0);
        ve.setType(9, IVeNft.EscrowType.MANAGED);
        vm.startPrank(user);
        ve.approve(address(box), 9);
        vm.expectRevert(LeafNftLockbox.BadNft.selector);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 9, user);
        vm.stopPrank();
    }

    function testRejectsLocked() public {
        ve.mint(user, 11, int128(uint128(50e18)), true, 0);
        ve.setType(11, IVeNft.EscrowType.LOCKED);
        vm.startPrank(user);
        ve.approve(address(box), 11);
        vm.expectRevert(LeafNftLockbox.BadNft.selector);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 11, user);
        vm.stopPrank();
    }

    function testRejectsVoted() public {
        ve.mint(user, 12, int128(uint128(10e18)), true, 0);
        ve.setVoted(12, true);
        vm.startPrank(user);
        ve.approve(address(box), 12);
        vm.expectRevert(LeafNftLockbox.BadNft.selector);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 12, user);
        vm.stopPrank();
    }

    function testRejectsAttached() public {
        ve.mint(user, 13, int128(uint128(10e18)), true, 0);
        ve.setAttachments(13, 1);
        vm.startPrank(user);
        ve.approve(address(box), 13);
        vm.expectRevert(LeafNftLockbox.BadNft.selector);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 13, user);
        vm.stopPrank();
    }

    function testRejectsOversizeNft() public {
        ve.mint(user, 14, int128(uint128(100_001e18)), true, 0);
        vm.startPrank(user);
        ve.approve(address(box), 14);
        vm.expectRevert(LeafNftLockbox.CapExceeded.selector);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 14, user);
        vm.stopPrank();
    }

    function testCannotPullNftAsYield() public {
        _wrap(1, 10e18);
        vm.startPrank(owner);
        box.setConvertYieldToHype(true);
        box.setHarvester(address(this));
        vm.expectRevert(LeafVePolicy.ForbiddenVeCall.selector);
        box.pullYield(IERC20(address(ve)), address(0xC0));
        vm.stopPrank();
    }

    function testCannotPullAero() public {
        _wrap(21, 10e18);
        vm.startPrank(owner);
        box.setConvertYieldToHype(true);
        vm.stopPrank();
        vm.expectRevert(LeafVePolicy.ForbiddenVeCall.selector);
        box.pullYield(IERC20(LeafVePolicy.AERO), address(0xC0));
    }

    function testBribeIsYieldNotPrincipal() public {
        _wrap(2, 10e18);
        bribe.mint(address(box), 5e18);
        vm.startPrank(owner);
        box.setConvertYieldToHype(true);
        box.setHarvester(address(this));
        vm.stopPrank();
        box.pullYield(bribe, address(0xC0));
        assertEq(box.totalLocked(), 10e18);
        assertEq(bribe.balanceOf(address(0xC0)), 5e18);
        assertEq(ve.ownerOf(2), address(box));
    }

    function testPrincipalFrozenAcrossRebaseSecondWrapAndBribe() public {
        _wrap(41, 10e18);
        ve.setLocked(41, int128(uint128(12e18)), true, 0);
        _wrap(42, 20e18);
        bribe.mint(address(box), 7e18);
        vm.prank(owner);
        box.setConvertYieldToHype(true);
        box.pullYield(bribe, address(0xC0));
        assertEq(box.principalOf(41), 10e18);
        assertEq(box.principalOf(42), 20e18);
        assertEq(box.totalLocked(), 30e18);
        assertEq(ve.ownerOf(41), address(box));
        assertEq(ve.ownerOf(42), address(box));
        assertEq(bribe.balanceOf(address(0xC0)), 7e18);
        IVeNft.LockedBalance memory L = ve.locked(41);
        assertEq(uint256(int256(L.amount)), 12e18);
        box.reportNftHealth();
        assertEq(uint8(box.health()), uint8(LeafOApp.Health.Normal));
    }

    function testRejectsTokenIdZero() public {
        ve.mint(user, 0, int128(uint128(10e18)), true, 0);
        vm.startPrank(user);
        ve.approve(address(box), 0);
        vm.expectRevert(LeafNftLockbox.BadNft.selector);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 0, user);
        vm.stopPrank();
    }

    function testUnlockDegrades() public {
        _wrap(3, 10e18);
        ve.setLocked(3, int128(uint128(10e18)), false, block.timestamp + 30 days);
        box.reportNftHealth();
        assertEq(uint8(box.health()), uint8(LeafOApp.Health.Degraded));
        ve.mint(user, 4, int128(uint128(10e18)), true, 0);
        vm.startPrank(user);
        ve.approve(address(box), 4);
        vm.expectRevert(LeafOApp.NotHealthy.selector);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 4, user);
        vm.stopPrank();
    }

    function testAmountDropDegrades() public {
        _wrap(31, 10e18);
        ve.setLocked(31, int128(uint128(9e18)), true, 0);
        box.reportNftHealth();
        assertEq(uint8(box.health()), uint8(LeafOApp.Health.Degraded));
    }

    function testBurnedNftDegrades() public {
        _wrap(32, 10e18);
        ve.burn(32);
        box.reportNftHealth();
        assertEq(uint8(box.health()), uint8(LeafOApp.Health.Degraded));
    }

    function testRebaseDoesNotDegrade() public {
        _wrap(33, 10e18);
        ve.setLocked(33, int128(uint128(11e18)), true, 0);
        box.reportNftHealth();
        assertEq(uint8(box.health()), uint8(LeafOApp.Health.Normal));
        assertEq(box.principalOf(33), 10e18);
        assertEq(box.totalLocked(), 10e18);
    }

    function testCannotRestoreWhileUnhealthy() public {
        _wrap(34, 10e18);
        ve.setLocked(34, int128(uint128(10e18)), false, block.timestamp + 30 days);
        box.reportNftHealth();
        vm.prank(owner);
        vm.expectRevert(LeafOApp.NotSolvent.selector);
        box.restoreHealth(LeafOApp.Health.Normal);
    }

    function testDestMarketOnly() public {
        vm.prank(owner);
        LeafClosedOFT oft = new LeafClosedOFT("Hyperleaf veAERO", "hveAERO", 0, address(ep), owner, guardian);
        assertFalse(oft.redeemEnabled());
        vm.expectRevert(LeafClosedOFT.ExitViaMarketOnly.selector);
        oft.send(30184, bytes32(uint256(uint160(user))), 1, user);
    }

    function testNoInboundRedeem() public {
        bytes memory payload = box.encodeBridge(bytes32(uint256(uint160(user))), 1);
        vm.prank(address(ep));
        vm.expectRevert(LeafNftLockbox.InboundOnly.selector);
        box.lzReceive(
            ILayerZeroEndpointV2.Origin(30367, bytes32(uint256(uint160(address(1)))), 1),
            bytes32(uint256(1)),
            payload,
            address(0),
            ""
        );
    }
}
