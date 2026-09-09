// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {EpochHNestGate} from "../src/EpochHNestGate.sol";

/// @notice HyperEVM 999 only. Wrap-branch Gate (5-arg ctor). Do NOT use
///         feat/nest-8d-withdraw-gate / 7cd3134 (4-arg, no guardian, no tranches).
contract DeployEpochHNestGate is Script {
    address constant LIVE_VAULT = 0x4f6615761A772e10d7f802B1C29654ABD90fF30d;
    address constant WHYPE = 0x5555555555555555555555555555555555555555;

    function run() external {
        require(block.chainid == 999, "HyperEVM 999");
        address owner = vm.envAddress("OWNER");
        address keeper = vm.envAddress("KEEPER");
        address guardian = vm.envAddress("GUARDIAN");
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        require(owner != guardian && owner != keeper, "role collision");
        require(guardian != address(0) && keeper != address(0) && feeRecipient != address(0), "zero role");

        vm.startBroadcast();
        EpochHNestGate gate = new EpochHNestGate(LIVE_VAULT, WHYPE, keeper, guardian, feeRecipient);
        gate.transferOwnership(owner);
        vm.stopBroadcast();

        require(gate.MAX_TRANCHES_PER_EPOCH() == 32, "wrong binary: no tranches");
        require(gate.HYPE_FINALIZE_DELAY() == 1 days, "wrong binary: no finalize delay");
        require(gate.guardian() == guardian, "guardian");

        console2.log("EpochHNestGate", address(gate));
        console2.log("pendingOwner", gate.pendingOwner());
        console2.log("ABANDON old gate 0xB4C43e9cE08ff5540e0E240dB7784f47231d519B");
        console2.log("Owner must acceptOwnership. Do not send users to the old gate.");
    }
}
