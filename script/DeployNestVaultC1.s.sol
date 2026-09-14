// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {NestVaultC1} from "../src/NestVaultC1.sol";
import {HNest} from "../src/HNest.sol";
import {HevAdapter} from "../src/HevAdapter.sol";
import {HyperEVMAddresses} from "../src/config/HyperEVMAddresses.sol";

/**
 * @title DeployNestVaultC1
 * @notice HyperEVM 999 only. Deploys the C1 vault (no redeem, permanent lock).
 *         The v1 vault 0x4f6615… is abandoned — never point this script at it.
 *
 *         Adapter <-> vault is circular: HevAdapter needs the vault address, the vault
 *         constructor wants the adapter. Same nonce-prediction pattern as Deploy.s.sol:
 *         HevAdapter (nonce n, vault=0), HNest (n+1, predicted vault), vault (n+2),
 *         then adapter.setVault. If HNEST is pre-deployed (3M block gas limit), the
 *         vault deploys at nonce n+1 instead.
 *
 *         Deposits are intentionally left DISABLED. Manual next steps (see
 *         docs/DEPLOYMENT_CHECKLIST.md):
 *           1. Deploy EpochHNestGate with VAULT_ADDRESS = vault (script/DeployEpochHNestGate.s.sol)
 *           2. Owner: vault.setDepositGate(gate)  — ONE-SHOT, verify address twice
 *           3. Readback: require gate.vault() == vault && vault.depositGate() == gate
 *           4. Owner: vault.setDepositsEnabled(true)
 *
 * Env: PRIVATE_KEY, FEE_RECIPIENT, KEEPER required. GUARDIAN, DEPOSIT_CAP, NEST_TOKEN,
 *      VE_NEST, HYPE_TOKEN (default WHYPE), HNEST (pre-deployed), VOTER,
 *      VIRTUAL_REWARDER, VE_NEST_DISTRIBUTOR, HEV_MANAGED_TOKEN_ID optional.
 */
contract DeployNestVaultC1 is Script {
    address constant WHYPE = 0x5555555555555555555555555555555555555555;

    function run() external {
        require(block.chainid == 999, "HyperEVM 999");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        address keeper = vm.envAddress("KEEPER");
        address guardian = vm.envOr("GUARDIAN", address(0)); // address(0) disables the pause role — decide explicitly
        uint256 depositCap = vm.envOr("DEPOSIT_CAP", uint256(0));
        address nestToken = vm.envOr("NEST_TOKEN", HyperEVMAddresses.NEST);
        address veNest = vm.envOr("VE_NEST", HyperEVMAddresses.VE_NEST);
        address hypeToken = vm.envOr("HYPE_TOKEN", WHYPE);
        address preHNest = vm.envOr("HNEST", address(0));
        address voter = vm.envOr("VOTER", HyperEVMAddresses.VOTER);
        address virtualRewarder = vm.envOr("VIRTUAL_REWARDER", HyperEVMAddresses.VIRTUAL_REWARDER);
        address veNestDistributor = vm.envOr("VE_NEST_DISTRIBUTOR", HyperEVMAddresses.VE_NEST_DISTRIBUTOR);
        uint256 managedTokenId = vm.envOr("HEV_MANAGED_TOKEN_ID", HyperEVMAddresses.HEV_MANAGED_TOKEN_ID);
        address merkle = HyperEVMAddresses.NEST_HYPE_MERKLE;

        uint64 n0 = vm.getNonce(deployer);
        // With a fresh HNest the vault is the 3rd tx (n0+2); with a pre-deployed HNEST it is the 2nd (n0+1).
        address predictedVault = vm.computeCreateAddress(deployer, preHNest == address(0) ? n0 + 2 : n0 + 1);

        vm.startBroadcast(pk);
        HevAdapter adapter =
            new HevAdapter(veNest, voter, hypeToken, address(0), virtualRewarder, veNestDistributor, managedTokenId);
        HNest hNest = preHNest == address(0) ? new HNest(predictedVault) : HNest(preHNest);
        NestVaultC1 vault = new NestVaultC1(
            nestToken, veNest, hypeToken, address(adapter), feeRecipient, keeper, guardian, depositCap, address(hNest), merkle
        );
        require(address(vault) == predictedVault, "vault address mismatch");
        adapter.setVault(address(vault));
        vm.stopBroadcast();

        // Post-deploy asserts.
        require(address(vault.hNest()) == address(hNest), "hNest mismatch");
        require(hNest.vault() == address(vault), "hNest.vault mismatch");
        require(address(vault.merkleAirdrop()) == merkle, "merkle mismatch");
        require(address(vault.hevAdapter()) == address(adapter), "adapter mismatch");
        require(adapter.vault() == address(vault), "adapter.vault mismatch");
        require(!vault.depositsEnabled(), "deposits must start disabled");
        require(vault.depositGate() == address(0), "gate must be unset");

        console2.log("HevAdapter", address(adapter));
        console2.log("NestVaultC1", address(vault));
        console2.log("HNest", address(hNest));
        console2.log("merkle", merkle);
        console2.log("guardian", guardian);
        console2.log("depositCap", depositCap);
        console2.log("depositsEnabled (must be false)", vault.depositsEnabled());
        console2.log("NEXT: deploy EpochHNestGate with VAULT_ADDRESS=vault; Owner setDepositGate(gate);");
        console2.log("NEXT: verify gate.vault()==vault; only then Owner setDepositsEnabled(true).");
    }
}
