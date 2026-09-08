// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {CanaryInner} from "src/lz/CanaryInner.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice Base mainnet toy wrap. Deploys LEAFTEST + adapter. Never a real inner.
contract DeployCanarySource is Script {
    function run() external {
        require(block.chainid == 8453, "Base 8453");
        require(vm.envOr("INNER_TOKEN", address(0)) == address(0), "no INNER_TOKEN");
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = vm.envOr("DEPOSIT_CAP", uint256(5e16));
        AssetCatalog.Listing memory a = AssetCatalog.get("hcanary");
        require(a.innerMainnet == address(0), "canary has no production inner");

        vm.startBroadcast();
        CanaryInner inner = new CanaryInner(owner);
        LeafOFTAdapter adapter =
            new LeafOFTAdapter(address(inner), A.ENDPOINT_BASE, owner, guardian, feeRecipient, cap);
        vm.stopBroadcast();

        console2.log("ASSET hcanary");
        console2.log("CanaryInner", address(inner));
        console2.log("LeafOFTAdapter", address(adapter));
        console2.log("cap", cap);
    }
}
