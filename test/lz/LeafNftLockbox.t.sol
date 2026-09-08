// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafNftLockbox} from "src/lz/LeafNftLockbox.sol";
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
        ve.mint(user, 7, int128(uint128(100e18)), true, 0);
        vm.startPrank(user);
        ve.approve(address(box), 7);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 7, user);
        vm.stopPrank();
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

    function testCannotPullNftAsYield() public {
        ve.mint(user, 1, int128(uint128(10e18)), true, 0);
        vm.startPrank(user);
        ve.approve(address(box), 1);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 1, user);
        vm.stopPrank();
        vm.startPrank(owner);
        box.setConvertYieldToHype(true);
        box.setHarvester(address(this));
        vm.expectRevert(LeafNftLockbox.BadNft.selector);
        box.pullYield(IERC20(address(ve)), address(0xC0));
        vm.stopPrank();
    }

    function testBribeIsYieldNotPrincipal() public {
        ve.mint(user, 2, int128(uint128(10e18)), true, 0);
        vm.startPrank(user);
        ve.approve(address(box), 2);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 2, user);
        vm.stopPrank();
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
