// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";

abstract contract PegReady is Test {
    bytes32 internal constant TAG = keccak256("test-listing");

    function _openSrc(LeafOApp src, address owner_, uint256 cap) internal {
        vm.startPrank(owner_);
        src.setListingTag(TAG);
        src.setLimits(cap, cap);
        src.openBridge();
        vm.stopPrank();
    }

    function _openPair(LeafOApp src, LeafOFT dst, address owner_, uint256 cap) internal {
        vm.startPrank(owner_);
        src.setListingTag(TAG);
        src.setLimits(cap, cap);
        dst.setListingTag(TAG);
        dst.setLimits(cap, cap);
        dst.setSupplyCap(cap);
        src.openBridge();
        dst.openBridge();
        vm.stopPrank();
    }

    function _msg(LeafOApp app, address to, uint256 amount) internal view returns (bytes memory) {
        return app.encodeBridge(bytes32(uint256(uint160(to))), amount);
    }
}
