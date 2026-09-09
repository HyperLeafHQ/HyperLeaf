// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {OptionsBuilder} from "src/lz/OptionsBuilder.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockEndpointOptions is ILayerZeroEndpointV2 {
    bytes public lastOptions;
    uint32 public lastDstEid;

    function eid() external pure returns (uint32) {
        return 30101;
    }

    function send(MessagingParams calldata p, address) external payable returns (MessagingReceipt memory r) {
        lastOptions = p.options;
        lastDstEid = p.dstEid;
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

contract LeafSendOptionsTest is Test {
    MockEndpointOptions ep;
    MockERC20 inner;
    LeafOFTAdapter adapter;
    LeafInboundLockbox inbound;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address user = address(0xCAFE);

    uint32 constant EVM = 30367;
    uint32 constant SOL = 30168;

    function setUp() public {
        ep = new MockEndpointOptions();
        inner = new MockERC20("INNER", "INR");
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, address(0xFEE), 10e18);
        inbound = new LeafInboundLockbox(address(inner), address(ep), owner, guardian, address(0xFEE), 10e18);
        adapter.setPeer(EVM, address(1));
        adapter.setPeer(SOL, keccak256("sol-peer"));
        inbound.setPeer(EVM, address(1));
        inbound.setPeer(SOL, keccak256("sol-peer"));
        _open(adapter);
        _open(inbound);
        vm.stopPrank();
        inner.mint(user, 4e18);
        vm.deal(user, 1 ether);
    }

    function _open(LeafOFTAdapter box) internal {
        box.setPeer(EVM, address(1));
        box.setListingTag(bytes32("HLBTC"));
        box.setLimits(1e18, 2e18);
        box.setInnerSupplyCeiling(10e18);
        box.openBridge();
    }

    function _open(LeafInboundLockbox box) internal {
        box.setPeer(EVM, address(1));
        box.setListingTag(bytes32("HLBTC"));
        box.setLimits(1e18, 2e18);
        box.setInnerSupplyCeiling(10e18);
        box.openBridge();
    }

    function testAdapterSendOptionsMatchQuoteForEvmAndSolana() public {
        bytes memory evmOpt = OptionsBuilder.lzReceiveOption(200_000);
        bytes memory solOpt = OptionsBuilder.lzReceiveOption(400_000);

        vm.startPrank(user);
        inner.approve(address(adapter), 2e18);
        adapter.send{value: 0.01 ether}(EVM, bytes32(uint256(uint160(user))), 1e18, user);
        assertEq(ep.lastDstEid(), EVM);
        assertEq(ep.lastOptions(), evmOpt);

        bytes32 solTo = bytes32(uint256(uint160(user)) << 96); // 32-byte pubkey, not left-padded 20
        adapter.send{value: 0.01 ether}(SOL, keccak256("sol"), 1e18, user);
        assertEq(ep.lastDstEid(), SOL);
        assertEq(ep.lastOptions(), solOpt);
        vm.stopPrank();
        solTo;
    }

    function testInboundSendOptionsMatchQuoteForEvmAndSolana() public {
        bytes memory evmOpt = OptionsBuilder.lzReceiveOption(200_000);
        bytes memory solOpt = OptionsBuilder.lzReceiveOption(400_000);

        vm.startPrank(user);
        inner.approve(address(inbound), 2e18);
        inbound.send{value: 0.01 ether}(EVM, bytes32(uint256(uint160(user))), 1e18, user);
        assertEq(ep.lastDstEid(), EVM);
        assertEq(ep.lastOptions(), evmOpt);

        inbound.send{value: 0.01 ether}(SOL, keccak256("sol"), 1e18, user);
        assertEq(ep.lastDstEid(), SOL);
        assertEq(ep.lastOptions(), solOpt);
        vm.stopPrank();
    }
}
