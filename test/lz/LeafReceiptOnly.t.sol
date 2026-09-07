// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

/// @dev gSOON / sWBERA: transferable receipt. Flag any 4626 unbond / cooldown.
contract SpyReceipt is ERC20 {
    mapping(bytes4 => uint256) public hits;

    constructor() ERC20("gSOON", "gSOON") {}

    function mint(address to, uint256 a) external {
        _mint(to, a);
    }

    function _count() internal {
        hits[msg.sig]++;
    }

    function transfer(address to, uint256 v) public override returns (bool) {
        _count();
        return super.transfer(to, v);
    }

    function transferFrom(address f, address t, uint256 v) public override returns (bool) {
        _count();
        return super.transferFrom(f, t, v);
    }

    function approve(address s, uint256 v) public override returns (bool) {
        _count();
        return super.approve(s, v);
    }

    fallback() external payable {
        hits[msg.sig]++;
    }

    receive() external payable {
        hits[bytes4(0)]++;
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 1;
    }
    function send(MessagingParams calldata p, address) external payable returns (MessagingReceipt memory r) {
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

contract LeafReceiptOnlyTest is PegReady {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    SpyReceipt inner;
    LeafOFTAdapter adapter;
    LeafOFT oft;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address user = address(0xCAFE);
    uint32 constant SRC = 30102;
    uint32 constant DST = 30367;

    // gSOON 7d + sWBERA 7d NFT queue
    bytes4 constant WITHDRAW = 0xb460af94;
    bytes4 constant REDEEM = 0xba087652;
    bytes4 constant QUEUE_WITHDRAW = 0x50b3f984;
    bytes4 constant QUEUE_REDEEM = 0x9ad82aa0;
    bytes4 constant COMPLETE1 = 0x38248a0c;
    bytes4 constant COMPLETE2 = 0x06866fdc;
    bytes4 constant CANCEL_Q = 0x1b0aed2c;
    bytes4 constant DEPOSIT = 0x6e553f65;
    bytes4 constant DEPOSIT_NATIVE = 0xf0194945;
    bytes4 constant MINT4626 = 0x94bf804d;
    bytes4 constant COOLDOWN_SHARES = 0x9343d9e1;
    bytes4 constant COOLDOWN_ASSETS = 0xcdac52ed;
    bytes4 constant CLAIM_ADDR = 0x1e83409a;

    function setUp() public {
        epSrc = new MockEndpoint();
        epDst = new MockEndpoint();
        inner = new SpyReceipt();
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(epSrc), owner, guardian, feeTo, 1_000e18);
        oft = new LeafOFT("hgSOON", "hgSOON", address(epDst), owner, guardian);
        adapter.setPeer(DST, address(oft));
        oft.setPeer(SRC, address(adapter));
        vm.stopPrank();
        _openPair(adapter, oft, owner, 1_000e18);
        inner.mint(user, 100e18);
        vm.deal(user, 1 ether);
    }

    function _noUnbond() internal view {
        assertEq(inner.hits(WITHDRAW), 0);
        assertEq(inner.hits(REDEEM), 0);
        assertEq(inner.hits(QUEUE_WITHDRAW), 0);
        assertEq(inner.hits(QUEUE_REDEEM), 0);
        assertEq(inner.hits(COMPLETE1), 0);
        assertEq(inner.hits(COMPLETE2), 0);
        assertEq(inner.hits(CANCEL_Q), 0);
        assertEq(inner.hits(DEPOSIT), 0);
        assertEq(inner.hits(DEPOSIT_NATIVE), 0);
        assertEq(inner.hits(MINT4626), 0);
        assertEq(inner.hits(COOLDOWN_SHARES), 0);
        assertEq(inner.hits(COOLDOWN_ASSETS), 0);
        assertEq(inner.hits(CLAIM_ADDR), 0);
    }

    function testWrapAndUnwrapNeverTouchesVaultExit() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        bytes memory mintPayload = _msg(oft, user, 10e18);
        ILayerZeroEndpointV2.Origin memory oIn = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(adapter)))), nonce: 1
        });
        vm.prank(address(epDst));
        oft.lzReceive(oIn, bytes32(uint256(1)), mintPayload, address(0), "");
        vm.prank(user);
        oft.sendTo{value: 0.01 ether}(SRC, user, 10e18);
        bytes memory burnPayload = _msg(adapter, user, 10e18);
        ILayerZeroEndpointV2.Origin memory oOut = ILayerZeroEndpointV2.Origin({
            srcEid: DST, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1
        });
        vm.prank(address(epSrc));
        adapter.lzReceive(oOut, bytes32(uint256(2)), burnPayload, address(0), "");
        assertEq(inner.balanceOf(user), 100e18);
        assertEq(oft.totalSupply(), 0);
        _noUnbond();
        vm.startPrank(owner);
        adapter.setConverter(owner);
        vm.expectRevert(LeafOFTAdapter.CannotPullInner.selector);
        adapter.pullYield(inner, owner);
        vm.stopPrank();
        _noUnbond();
    }

    function testCatalogReceiptListingsAreLiquid() public pure {
        AssetCatalog.Listing memory g = AssetCatalog.get("hgsoon");
        AssetCatalog.Listing memory s = AssetCatalog.get("hswbera");
        assertEq(uint8(g.kind), uint8(AssetCatalog.Kind.Liquid));
        assertEq(uint8(s.kind), uint8(AssetCatalog.Kind.Liquid));
        assertEq(g.lockSeconds, 0);
        assertEq(s.lockSeconds, 0);
    }
}
