// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {EpochHNestGateV2} from "../src/EpochHNestGateV2.sol";
import {INestVaultDepositV2} from "../src/EpochHNestGateV2.sol";

/// @notice HyperEVM 999 only. Gate V2 for a *new* NestVaultC1 instance.
///         Do not point this at live C1 `0xaE7C…` — its depositGate is frozen.
///         Do not deploy V1 `EpochHNestGate` for the new vault.
contract DeployEpochHNestGateV2 is Script {
    address constant WHYPE = 0x5555555555555555555555555555555555555555;
    address constant LIVE_C1 = 0xaE7C4B1bdbEeD5B5923D856Ae53DF357CC86755c;

    function run() external {
        require(block.chainid == 999, "HyperEVM 999");
        address vault = vm.envAddress("VAULT_ADDRESS");
        require(vault != address(0), "VAULT_ADDRESS required");
        require(vault.code.length > 0, "VAULT_ADDRESS has no code");
        require(vault != LIVE_C1, "C1 gate is frozen; use a new vault");
        address owner = vm.envAddress("OWNER");
        address keeper = vm.envAddress("KEEPER");
        address guardian = vm.envAddress("GUARDIAN");
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        require(owner != guardian && owner != keeper, "role collision");
        require(guardian != address(0) && keeper != address(0) && feeRecipient != address(0), "zero role");

        vm.startBroadcast();
        EpochHNestGateV2 gate = new EpochHNestGateV2(vault, WHYPE, keeper, guardian, feeRecipient);
        gate.transferOwnership(owner);
        vm.stopBroadcast();

        require(address(gate.vault()) == vault, "vault");
        require(gate.HNEST_MINT_DELAY() == 8 days, "delay");
        require(gate.guardian() == guardian, "guardian");
        require(INestVaultDepositV2(vault).hNest() == address(gate.hNest()), "hNest");

        console2.log("EpochHNestGateV2", address(gate));
        console2.log("vault", vault);
        console2.log("pendingOwner", gate.pendingOwner());
        console2.log("NEXT: vault.setDepositGate(gate) then readback; deposits stay false");
    }
}
