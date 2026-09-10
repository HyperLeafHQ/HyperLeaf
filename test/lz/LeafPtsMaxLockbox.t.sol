// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LeafPtsMaxLockbox} from "src/lz/LeafPtsMaxLockbox.sol";
import {LeafPtsMaxPolicy as P} from "src/lz/LeafPtsMaxPolicy.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockPts is ERC20 {
    constructor() ERC20("River Pts", "Pts") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockSRiver is ERC721 {
    uint256 public nextId = 1;
    constructor() ERC721("sRIVER_V2", "sRIVER") {}
    function mintTo(address to) external returns (uint256 id) {
        id = nextId++;
        _safeMint(to, id);
    }
}

contract MockConvert {
    IERC20 public pts;
    MockSRiver public nft;
    uint256 public lastEpoch;
    uint256 public lastP1;
    uint256 public riverPerPts = 39477 * 1e14 / 100_000; // ~0.0039477

    constructor(IERC20 pts_, MockSRiver nft_) {
        pts = pts_;
        nft = nft_;
    }

    fallback() external {
        require(bytes4(msg.data) == bytes4(0x03063b98), "sel");
        (uint256 ptsIn, uint256 p1, uint256 epoch, uint256 minOut) =
            abi.decode(msg.data[4:], (uint256, uint256, uint256, uint256));
        lastP1 = p1;
        lastEpoch = epoch;
        require(pts.transferFrom(msg.sender, address(this), ptsIn), "pts");
        uint256 riverOut = ptsIn * riverPerPts / 1e18;
        require(riverOut >= minOut, "min");
        nft.mintTo(msg.sender);
        bytes memory out = abi.encode(riverOut);
        assembly {
            return(add(out, 32), mload(out))
        }
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30102;
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

contract LeafPtsMaxLockboxTest is PegReady {
    MockEndpoint ep;
    MockPts pts;
    MockSRiver nft;
    MockConvert conv;
    LeafPtsMaxLockbox box;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address user = address(0xBEEF);

    function setUp() public {
        ep = new MockEndpoint();
        pts = new MockPts();
        nft = new MockSRiver();
        conv = new MockConvert(pts, nft);
        vm.prank(owner);
        box = new LeafPtsMaxLockbox(address(pts), address(conv), address(nft), address(ep), owner, guardian, feeTo, 1_000 ether);
        vm.prank(owner);
        box.setPeer(30367, address(1));
        _openSrc(box, owner, 1_000 ether);
        pts.mint(user, 100_000 ether);
        vm.deal(user, 1 ether);
    }

    function testCatalogNotABatch() public {
        AssetCatalog.Listing memory a = AssetCatalog.get("ptsmax");
        assertEq(a.sourceChainIdMain, 56);
        assertEq(a.innerMainnet, P.PTS);
        assertFalse(a.productionEvm);
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("ptsmax");
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }

    function testWrapMintsRiverNotPts() public {
        vm.startPrank(user);
        pts.approve(address(box), 100_000 ether);
        box.sendTo{value: 0.01 ether}(30367, user, 100_000 ether, 0);
        vm.stopPrank();
        uint256 riverOut = 100_000 ether * conv.riverPerPts() / 1e18;
        assertEq(box.totalLocked(), riverOut);
        assertEq(box.heldCount(), 1);
        assertEq(nft.ownerOf(1), address(box));
        assertEq(box.principalOf(1), riverOut);
        assertEq(conv.lastEpoch(), 7);
        assertEq(conv.lastP1(), 1);
        assertEq(pts.balanceOf(address(box)), 0);
    }

    function testInboundBlocked() public {
        bytes memory payload = _msg(box, user, 1 ether);
        ILayerZeroEndpointV2.Origin memory origin =
            ILayerZeroEndpointV2.Origin({srcEid: 30367, sender: bytes32(uint256(uint160(address(1)))), nonce: 1});
        vm.prank(address(ep));
        vm.expectRevert(LeafPtsMaxLockbox.InboundOnly.selector);
        box.lzReceive(origin, bytes32(uint256(1)), payload, address(this), "");
    }

    function testMerkleOffByDefault() public {
        bytes32[] memory proof;
        vm.expectRevert(LeafPtsMaxLockbox.MerkleOff.selector);
        box.claimWeeklyPts(0, 1, proof);
    }

    function testUnstakeSelectorForbidden() public view {
        assertTrue(LeafForbiddenSelectors.forbidden(P.UNSTAKE_SEL));
        assertEq(P.EPOCH_MAX, 7);
        assertEq(P.UNLOCK_AT, 1_854_021_600);
        assertEq(P.CONVERT_SEL, bytes4(0x03063b98));
    }

    function testV1NftRejected() public {
        vm.prank(owner);
        vm.expectRevert(P.V1Forbidden.selector);
        new LeafPtsMaxLockbox(address(pts), address(conv), P.SRIVER_V1, address(ep), owner, guardian, feeTo, 1);
    }

    function testHealthDegradesIfNftLeaves() public {
        vm.startPrank(user);
        pts.approve(address(box), 100_000 ether);
        box.sendTo{value: 0.01 ether}(30367, user, 100_000 ether, 0);
        vm.stopPrank();
        vm.prank(address(box));
        nft.transferFrom(address(box), user, 1);
        box.reportNftHealth();
        assertEq(uint8(box.health()), uint8(1)); // Health.Degraded
    }
}
