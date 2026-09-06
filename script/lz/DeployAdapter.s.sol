// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

contract DeployAdapter is Script {
    address constant SKAITO = 0x548D3B444da39686d1a6F1544781d154e7cD1EF7;

    function run() external {
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        address token = vm.envOr("INNER_TOKEN", SKAITO);
        uint256 cap = vm.envOr("DEPOSIT_CAP", uint256(0));
        uint256 chainId = block.chainid;
        address endpoint = chainId == 8453 ? A.ENDPOINT_BASE : A.ENDPOINT_BASE_SEPOLIA;
        vm.startBroadcast();
        LeafOFTAdapter adapter = new LeafOFTAdapter(token, endpoint, owner, guardian, feeRecipient, cap);
        console2.log("LeafOFTAdapter", address(adapter));
        vm.stopBroadcast();
    }
}
