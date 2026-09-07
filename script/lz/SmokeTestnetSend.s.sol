// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice Approve mock inner and sendTo HyperEVM testnet. Overpays LZ fee.
contract SmokeTestnetSend is Script {
    function run() external {
        address source = vm.envAddress("SOURCE");
        address inner = vm.envAddress("INNER");
        address to = vm.envOr("TO", vm.envAddress("OWNER"));
        uint256 amount = vm.envOr("AMOUNT", uint256(0.05 ether));
        uint32 dstEid = uint32(vm.envOr("DST_EID", uint256(A.EID_HYPEREVM_TESTNET)));

        uint256 fee = LeafOApp(source).quoteSend(dstEid, to, amount);
        uint256 pay = fee + (fee / 5) + 0.002 ether;
        console2.log("quote nativeFee", fee);
        console2.log("paying", pay);

        vm.startBroadcast();
        IERC20(inner).approve(source, amount);
        bytes32 guid = LeafOFTAdapter(source).sendTo{value: pay}(dstEid, to, amount);
        vm.stopBroadcast();

        console2.log("guid");
        console2.logBytes32(guid);
        console2.log("to", to);
        console2.log("amount", amount);
        console2.log("next: wait LZ, then dest OFT.balanceOf(to)");
    }
}
