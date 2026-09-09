// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockEndpointPeerFreeze is ILayerZeroEndpointV2 {
    error LZ_Unauthorized();

    mapping(address oapp => address delegate) public delegates;

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

    function setDelegate(address d) external {
        delegates[msg.sender] = d;
    }

    function setConfig(address oapp, address, SetConfigParam[] calldata) external {
        if (msg.sender != oapp && msg.sender != delegates[oapp]) revert LZ_Unauthorized();
    }

    function getConfig(address, address, uint32, uint32) external pure returns (bytes memory) {
        return "";
    }

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

    function testAllowInitializePathMatchesPeer() public view {
        ILayerZeroEndpointV2.Origin memory ok =
            ILayerZeroEndpointV2.Origin({srcEid: 30367, sender: bytes32(uint256(uint160(address(1)))), nonce: 1});
        ILayerZeroEndpointV2.Origin memory bad =
            ILayerZeroEndpointV2.Origin({srcEid: 30367, sender: bytes32(uint256(uint160(address(9)))), nonce: 1});
        assertTrue(adapter.allowInitializePath(ok));
        assertFalse(adapter.allowInitializePath(bad));
        assertEq(adapter.nextNonce(30367, ok.sender), 0);
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

    function testEndpointConfigStaysFrozenAfterCloseBridge() public {
        SetConfigParam[] memory params = new SetConfigParam[](0);

        vm.prank(owner);
        adapter.setEndpointConfig(address(0x1111), params);

        vm.prank(owner);
        adapter.openBridge();

        vm.prank(owner);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        adapter.setEndpointConfig(address(0x1111), params);

        vm.prank(guardian);
        adapter.closeBridge();

        vm.prank(owner);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        adapter.setEndpointConfig(address(0x1111), params);
    }

    function testOwnerIsNeverEndpointDelegate() public {
        assertEq(ep.delegates(address(adapter)), address(0));

        SetConfigParam[] memory params = new SetConfigParam[](0);
        vm.prank(owner);
        adapter.setEndpointConfig(address(0x1111), params);

        vm.prank(owner);
        vm.expectRevert(MockEndpointPeerFreeze.LZ_Unauthorized.selector);
        ep.setConfig(address(adapter), address(0x1111), params);

        vm.prank(owner);
        adapter.openBridge();

        vm.prank(owner);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        adapter.setEndpointConfig(address(0x1111), params);

        vm.prank(owner);
        vm.expectRevert(MockEndpointPeerFreeze.LZ_Unauthorized.selector);
        ep.setConfig(address(adapter), address(0x1111), params);

        vm.prank(guardian);
        adapter.closeBridge();

        vm.prank(owner);
        vm.expectRevert(MockEndpointPeerFreeze.LZ_Unauthorized.selector);
        ep.setConfig(address(adapter), address(0x1111), params);
    }
}
