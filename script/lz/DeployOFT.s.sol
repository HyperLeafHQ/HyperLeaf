// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

contract DeployOFT is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        string memory name = vm.envOr("OFT_NAME", string("Hyperleaf sKAITO"));
        string memory symbol = vm.envOr("OFT_SYMBOL", string("hKAITO"));
        uint256 chainId = block.chainid;
        address endpoint = chainId == 999 ? A.ENDPOINT_HYPEREVM : A.ENDPOINT_HYPEREVM_TESTNET;
        vm.startBroadcast();
        LeafOFT oft = new LeafOFT(name, symbol, endpoint, owner, guardian);
        console2.log("LeafOFT", address(oft));
        vm.stopBroadcast();
    }
}
