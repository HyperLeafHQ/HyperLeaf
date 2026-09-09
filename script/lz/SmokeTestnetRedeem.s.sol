// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice Burn dest OFT back to source (L only). C1 must revert.
contract SmokeTestnetRedeem is Script {
    function run() external {
        address oft = vm.envAddress("OFT");
        address to = vm.envOr("TO", vm.envAddress("OWNER"));
        uint256 amount = vm.envOr("AMOUNT", uint256(0.05 ether));
        uint32 dstEid = uint32(vm.envOr("DST_EID", uint256(A.EID_BASE)));

        uint256 fee = LeafOApp(oft).quoteSend(dstEid, to, amount);
        uint256 pay = fee + (fee / 5) + 0.002 ether;
        console2.log("quote nativeFee", fee);

        vm.startBroadcast();
        bytes32 guid = LeafOFT(oft).sendTo{value: pay}(dstEid, to, amount);
        vm.stopBroadcast();

        console2.log("guid");
        console2.logBytes32(guid);
        console2.log("next: source inner.balanceOf(to) should rise");
    }
}
