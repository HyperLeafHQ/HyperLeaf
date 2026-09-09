// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafClaimEscrow} from "src/lz/LeafClaimEscrow.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice HyperEVM mainnet Leaf Market escrow. After the Leaf exists.
///         hNEST: LEAF=hNEST WANT=NEST REWARDER unset. Do not deploy Fill.
contract DeployClaimDest is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(block.chainid == 999, "HyperEVM 999");
        require(owner != guardian, "OWNER == GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        address leaf = vm.envAddress("LEAF");
        address want = vm.envAddress("WANT");
        address rewarder = vm.envOr("REWARDER", address(0));
        bytes32 rewardId = vm.envOr("REWARD_ID", bytes32(0));

        vm.startBroadcast();
        LeafClaimEscrow escrow = new LeafClaimEscrow(A.ENDPOINT_HYPEREVM, owner, guardian, feeRecipient);
        escrow.setMarket(leaf, want, rewardId, true);
        if (rewarder != address(0)) escrow.setRewarder(rewarder);
        vm.stopBroadcast();

        console2.log("LeafClaimEscrow", address(escrow));
        console2.log("LEAF", leaf);
        console2.log("WANT", want);
        console2.log("next: deploy Fill on source, then WirePeers OAPP=escrow PEER=fill ASSET=...");
    }
}
