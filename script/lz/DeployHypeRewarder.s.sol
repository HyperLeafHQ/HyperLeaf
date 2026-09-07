// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafHypeRewarder} from "src/lz/LeafHypeRewarder.sol";
import {HypeAddresses} from "src/lz/HypeAddresses.sol";

/// @notice HyperEVM 999 / 998. Then **in this order**:
///         OFT.setHypeRewarder(rewarder, listingId) — listingId one-shot
///         Rewarder.register(listingId, OFT) — reverts unless OFT already points here
///         source.setConvertYieldToHype(true)
contract DeployHypeRewarder is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        address hype = vm.envOr("WHYPE", HypeAddresses.WHYPE);
        if (block.chainid != 999 && block.chainid != 998) {
            revert("deploy on HyperEVM");
        }
        vm.startBroadcast();
        LeafHypeRewarder r = new LeafHypeRewarder(hype, owner, feeRecipient);
        console2.log("LeafHypeRewarder", address(r));
        console2.log("WHYPE", hype);
        vm.stopBroadcast();
    }
}
