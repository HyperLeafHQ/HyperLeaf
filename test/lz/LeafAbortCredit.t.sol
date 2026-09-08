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
    function getConfig(address, address, uint32, uint32) external pure returns (bytes memory) { return ""; }
    function skip(address, uint32, bytes32, uint64) external {}
}

contract LeafAbortCreditTest is Test {
    MockEndpointAbortCredit ep;
    MockERC20 inner;
    LeafOFTAdapter adapter;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address user = address(0xCAFE);
    address other = address(0xBEEF);

    function setUp() public {
        ep = new MockEndpointAbortCredit();
        inner = new MockERC20("INNER", "INR");

        vm.prank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, address(0xFEE), 1e18);

        vm.startPrank(owner);
        adapter.setPeer(30367, address(1));
        adapter.setListingTag(bytes32("HLBTC"));
        adapter.setLimits(1e18, 2e18);
        adapter.setInnerSupplyCeiling(1e18);
        adapter.openBridge();
        vm.stopPrank();

        inner.mint(user, 2e18);
        inner.mint(other, 2e18);
    }

    function _send(address from, uint256 amount) internal returns (bytes32 guid) {
        vm.startPrank(from);
        inner.approve(address(adapter), amount);
        guid = adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(from))), amount, from);
        vm.stopPrank();
    }

    function _halt() internal {
        vm.prank(guardian);
        adapter.setHealth(LeafOApp.Health.Halted);
    }

    function testCannotAbortUnrelatedCredit() public {
        _send(user, 1e18);
        _halt();

        bytes32 unrelated = keccak256("unrelated");
        vm.prank(owner);
        vm.expectRevert(LeafOFTAdapter.CreditNotPending.selector);
        adapter.abortCredit(unrelated, user);
    }

    function testCannotReuseSameGuid() public {
        bytes32 guid = _send(user, 1e18);
        uint256 before = inner.balanceOf(user);
        _halt();

        vm.prank(owner);
        adapter.abortCredit(guid, user);
        assertEq(inner.balanceOf(user), before + 1e18);

        vm.prank(owner);
        vm.expectRevert(LeafOFTAdapter.CreditAlreadyConsumed.selector);
        adapter.abortCredit(guid, user);
    }

    function testRecipientMustMatchOriginalSender() public {
        bytes32 guid = _send(user, 1e18);
        _halt();

        vm.prank(owner);
        vm.expectRevert(LeafOFTAdapter.CreditRecipientMismatch.selector);
        adapter.abortCredit(guid, other);
    }

    function testAbortAmountCannotBeCallerSelected() public {
        bytes32 guid = _send(user, 1e18);
        _halt();

        (address sender, uint32 dstEid, bytes32 dstPeer, bytes32 recipient, uint256 shares, bool consumed) =
            adapter.pendingCredits(guid);
        assertEq(sender, user);
        assertEq(dstEid, 30367);
        assertEq(dstPeer, bytes32(uint256(uint160(address(1)))));
        assertEq(recipient, bytes32(uint256(uint160(user))));
        assertEq(shares, 1e18);
        assertFalse(consumed);
    }

    function testAbortCannotDrainAnotherRecordedCredit() public {
        bytes32 userGuid = _send(user, 1e18);
        bytes32 otherGuid = _send(other, 1e18);
        _halt();

        uint256 userBefore = inner.balanceOf(user);
        uint256 otherBefore = inner.balanceOf(other);
        uint256 lockedBefore = adapter.totalLocked();

        vm.prank(owner);
        adapter.abortCredit(userGuid, user);

        assertEq(inner.balanceOf(user), userBefore + 1e18);
        assertEq(inner.balanceOf(other), otherBefore);
        assertEq(adapter.totalLocked(), lockedBefore - 1e18);

        (,,,,, bool consumedOther) = adapter.pendingCredits(otherGuid);
        assertFalse(consumedOther);
    }
}
