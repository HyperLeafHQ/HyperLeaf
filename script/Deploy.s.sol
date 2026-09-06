// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {NestVault} from "../src/NestVault.sol";
import {HNest} from "../src/HNest.sol";
import {HevAdapter} from "../src/HevAdapter.sol";
import {HyperEVMAddresses} from "../src/config/HyperEVMAddresses.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address hypeToken = vm.envAddress("HYPE_TOKEN");
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        address keeper = vm.envAddress("KEEPER");
        address guardian = vm.envOr("GUARDIAN", address(0));
        uint256 depositCap = vm.envOr("DEPOSIT_CAP", uint256(0));
        address nestToken = vm.envOr("NEST_TOKEN", HyperEVMAddresses.NEST);
        address veNest = vm.envOr("VE_NEST", HyperEVMAddresses.VE_NEST);
        address voter = vm.envOr("VOTER", HyperEVMAddresses.VOTER);
        address virtualRewarder = vm.envOr("VIRTUAL_REWARDER", HyperEVMAddresses.VIRTUAL_REWARDER);
        address veNestDistributor = vm.envOr("VE_NEST_DISTRIBUTOR", HyperEVMAddresses.VE_NEST_DISTRIBUTOR);
        uint256 managedTokenId = vm.envOr("HEV_MANAGED_TOKEN_ID", HyperEVMAddresses.HEV_MANAGED_TOKEN_ID);

        // HyperEVM block gasLimit=3M: deploy HNest then NestVault in separate txs.
        // Order: HevAdapter (n), HNest (n+1), NestVault (n+2)
        uint64 n0 = vm.getNonce(deployer);
        address predictedVault = vm.computeCreateAddress(deployer, n0 + 2);

        vm.startBroadcast(pk);
        HevAdapter adapter =
            new HevAdapter(veNest, voter, hypeToken, address(0), virtualRewarder, veNestDistributor, managedTokenId);
        HNest hNest = new HNest(predictedVault);
        NestVault vault = new NestVault(
            nestToken, veNest, hypeToken, address(adapter), feeRecipient, keeper, guardian, depositCap, address(hNest)
        );
        require(address(vault) == predictedVault, "vault address mismatch");
        require(address(vault.hNest()) == address(hNest), "hNest mismatch");
        adapter.setVault(address(vault));
        vm.stopBroadcast();

        console2.log("HevAdapter", address(adapter));
        console2.log("NestVault", address(vault));
        console2.log("HNest", address(vault.hNest()));
        console2.log("guardian", guardian);
        console2.log("HEV_STRATEGY", HyperEVMAddresses.HEV_STRATEGY);
        console2.log("managedTokenId", managedTokenId);
    }
}
