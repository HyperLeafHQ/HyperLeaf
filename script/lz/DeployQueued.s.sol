// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafRedeemQueue} from "src/lz/LeafRedeemQueue.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

contract DeployQueued is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = vm.envOr("DEPOSIT_CAP", uint256(1_000e18));
        uint64 delay = uint64(vm.envOr("REDEEM_DELAY", uint256(7 days)));
        uint256 chainId = block.chainid;

        vm.startBroadcast();
        if (chainId == 999 || chainId == 998) {
            string memory name = vm.envString("OFT_NAME");
            string memory symbol = vm.envString("OFT_SYMBOL");
            address endpoint = chainId == 999 ? A.ENDPOINT_HYPEREVM : A.ENDPOINT_HYPEREVM_TESTNET;
            LeafOFT oft = new LeafOFT(name, symbol, endpoint, owner, guardian);
            console2.log("LeafOFT", address(oft));
        } else {
            address inner = vm.envAddress("INNER_TOKEN");
            address endpoint = chainId == 56 ? A.ENDPOINT_BSC : A.ENDPOINT_BASE;
            LeafRedeemQueue q =
                new LeafRedeemQueue(inner, endpoint, owner, guardian, feeRecipient, cap, delay);
            console2.log("LeafRedeemQueue", address(q));
        }
        vm.stopBroadcast();
    }
}
