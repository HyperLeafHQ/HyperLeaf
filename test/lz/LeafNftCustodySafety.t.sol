// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {LeafNftLockbox} from "src/lz/LeafNftLockbox.sol";
import {IVeNft} from "src/lz/IVeNft.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract CustodyEndpoint is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) { return 30184; }
    function send(MessagingParams calldata, address) external payable returns (MessagingReceipt memory r) { r.guid = bytes32(uint256(1)); }
    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) { return MessagingFee(0, 0); }
    function setDelegate(address) external {}
    function setConfig(address, address, SetConfigParam[] calldata) external {}
    function getConfig(address, address, uint32, uint32) external pure returns (bytes memory) { return ""; }
    function skip(address, uint32, bytes32, uint64) external {}
}

contract MockVeCustody is ERC721 {
    mapping(uint256 => IVeNft.LockedBalance) internal _locked;
    mapping(uint256 => IVeNft.EscrowType) internal _types;
    mapping(uint256 => bool) internal _voted;
    mapping(uint256 => uint256) internal _attachments;

    constructor() ERC721("veAERO", "veAERO") {}

    function mint(address to, uint256 id, int128 amount) external {
        _mint(to, id);
        _locked[id] = IVeNft.LockedBalance(amount, 0, true);
        _types[id] = IVeNft.EscrowType.NORMAL;
    }

    function locked(uint256 id) external view returns (IVeNft.LockedBalance memory) { return _locked[id]; }
    function escrowType(uint256 id) external view returns (IVeNft.EscrowType) { return _types[id]; }
    function voted(uint256 id) external view returns (bool) { return _voted[id]; }
    function attachments(uint256 id) external view returns (uint256) { return _attachments[id]; }
}

contract LeafNftCustodySafetyTest is Test {
    CustodyEndpoint endpoint;
    MockVeCustody ve;
    LeafNftLockbox box;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address seller = address(0xCAFE);

    function setUp() public {
        endpoint = new CustodyEndpoint();
        ve = new MockVeCustody();
        vm.prank(owner);
        box = new LeafNftLockbox(address(ve), address(endpoint), owner, guardian, address(0xFEE), 1_000e18);
    }

    function testUnsolicitedVeTransferRevertsAndLeavesRegistryEmpty() public {
        ve.mint(seller, 1, 100e18);
        vm.startPrank(seller);
        vm.expectRevert(LeafNftLockbox.UnexpectedNftTransfer.selector);
        ve.safeTransferFrom(seller, address(box), 1);
        vm.stopPrank();

        assertEq(ve.ownerOf(1), seller);
        assertEq(box.heldCount(), 0);
        assertEq(box.totalLocked(), 0);
        assertEq(box.principalOf(1), 0);
    }
}
