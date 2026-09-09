// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockEndpointAbortCredit is ILayerZeroEndpointV2 {
    uint64 internal nonce;

    function eid() external pure returns (uint32) {
        return 30101;
    }

    function send(MessagingParams calldata p, address) external payable returns (MessagingReceipt memory r) {
        nonce++;
        r.guid = keccak256(abi.encode(nonce, p.dstEid, p.receiver, p.message));
        r.nonce = nonce;
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

/// @dev Adapter abortCredit is permanently disabled. An old GUID must never
///      authorize consumption of later users' backing.
contract LeafAbortCreditTest is Test {
    MockEndpointAbortCredit ep;
    MockERC20 inner;
    LeafOFTAdapter adapter;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address user = address(0xCAFE);

    function setUp() public {
        ep = new MockEndpointAbortCredit();
        inner = new MockERC20("INNER", "INR");

        vm.prank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, address(0xFEE), 10e18);

        vm.startPrank(owner);
        adapter.setPeer(30367, address(1));
        adapter.setListingTag(bytes32("HLBTC"));
        adapter.setLimits(1e18, 2e18);
        adapter.setInnerSupplyCeiling(10e18);
        adapter.openBridge();
        vm.stopPrank();

        inner.mint(user, 2e18);
        vm.deal(user, 1 ether);
        vm.deal(owner, 1 ether);
    }

    function testAbortCreditDisabledBeforeAndAfterHalt() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 1e18);
        bytes32 guid = adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 1e18, user);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(LeafOFTAdapter.ReentrantAbortRecoveryDisabled.selector);
        adapter.abortCredit(guid, user);

        vm.prank(guardian);
        adapter.setHealth(LeafOApp.Health.Halted);

        uint256 locked = adapter.totalLocked();
        uint256 userBal = inner.balanceOf(user);
        vm.prank(owner);
        vm.expectRevert(LeafOFTAdapter.ReentrantAbortRecoveryDisabled.selector);
        adapter.abortCredit(guid, user);
        assertEq(adapter.totalLocked(), locked);
        assertEq(inner.balanceOf(user), userBal);
    }
}
