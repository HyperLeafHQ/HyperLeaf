// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EpochHNestGateV3, INestVaultDepositV3} from "../src/EpochHNestGateV3.sol";

/// @notice HyperEVM 999 only. Deploys the V3 implementation and its proxy.
///         The proxy is the deposit gate. Do not point it at a vault whose
///         depositGate is already set (live V2 vault included). Not a GO.
contract DeployEpochHNestGateV3 is Script {
    address constant WHYPE = 0x5555555555555555555555555555555555555555;

    function run() external {
        require(block.chainid == 999, "HyperEVM 999");
        address vault = vm.envAddress("VAULT_ADDRESS");
        require(vault != address(0) && vault.code.length > 0, "VAULT_ADDRESS");
        require(INestVaultDepositV3(vault).depositGate() == address(0), "depositGate already frozen");

        address owner = vm.envAddress("OWNER");
        address keeper = vm.envAddress("KEEPER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != address(0) && keeper != address(0) && guardian != address(0), "zero role");
        require(owner != keeper && owner != guardian && keeper != guardian, "role collision");

        vm.startBroadcast();
        EpochHNestGateV3 impl = new EpochHNestGateV3();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(EpochHNestGateV3.initialize, (owner, vault, WHYPE, keeper, guardian))
        );
        vm.stopBroadcast();

        EpochHNestGateV3 gate = EpochHNestGateV3(address(proxy));
        require(gate.VERSION() == 3, "version");
        require(gate.HNEST_MINT_DELAY() == 8 days, "delay");
        require(address(gate.vault()) == vault, "vault");
        require(gate.owner() == owner, "owner");
        require(gate.keeper() == keeper, "keeper");

        console2.log("EpochHNestGateV3 proxy", address(proxy));
        console2.log("implementation", address(impl));
        console2.log("NEXT: vault.setDepositGate(proxy); deposits stay false");
    }
}
