// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockEndpointPeerFreeze is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30101;
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
    function getConfig(address, address, uint32, uint32) external pure returns (bytes memory) { return ""; }
    function skip(address, uint32, bytes32, uint64) external {}
}

contract LeafPeerFreezeTest is PegReady {
    MockEndpointPeerFreeze ep;
    MockERC20 inner;
    LeafOFTAdapter adapter;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);

    function setUp() public {
        ep = new MockEndpointPeerFreeze();
        inner = new MockERC20("INNER", "INR");
        vm.prank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, address(0xFEE), 1e18);

        vm.startPrank(owner);
        adapter.setPeer(30367, address(1));
        adapter.setPeer(40161, address(2));
        adapter.setListingTag(bytes32("HLBTC"));
        adapter.setLimits(1e18, 2e18);
        adapter.setInnerSupplyCeiling(1e18);
        vm.stopPrank();
    }

    function testPeerConfigurationCanFinishBeforeBridgeOpened() public {
        assertEq(adapter.peers(30367), bytes32(uint256(uint160(address(1)))));
        assertEq(adapter.peers(40161), bytes32(uint256(uint160(address(2)))));
        assertFalse(adapter.peersFrozen());
        assertFalse(adapter.bridgeOpen());
    }

    function testPeerCannotChangeAfterBridgeOpened() public {
        vm.prank(owner);
        adapter.openBridge();

        vm.prank(owner);
        vm.expectRevert(LeafOApp.PeerFrozen.selector);
        adapter.setPeer(30367, address(3));
    }

    function testNewPeerCannotBeAddedAfterBridgeOpened() public {
        vm.prank(owner);
        adapter.openBridge();

        vm.prank(owner);
        vm.expectRevert(LeafOApp.PeerFrozen.selector);
        adapter.setPeer(40231, address(4));
    }

    function testPeerCannotChangeAfterBridgeClosed() public {
        vm.prank(owner);
        adapter.openBridge();

        vm.prank(guardian);
        adapter.closeBridge();

        vm.prank(owner);
        vm.expectRevert(LeafOApp.PeerFrozen.selector);
        adapter.setPeer(30367, address(3));

        vm.prank(owner);
        vm.expectRevert(LeafOApp.PeerFrozen.selector);
        adapter.setPeer(40231, address(4));
    }
}
