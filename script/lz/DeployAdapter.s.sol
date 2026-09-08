// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice Mainnet L source. Batch 3: ASSET=hswbera on Berachain 80094 only.
///         Then ConfigureMainnetListing (ConvertToAssets + retain 1%).
///         Broadcast on the listing's sourceChainIdMain. Never a mock inner.
contract DeployAdapter is Script {
    function run() external {
        string memory id = vm.envString("ASSET");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(a.kind == AssetCatalog.Kind.Liquid, "not L");
        require(a.productionEvm, "not production evm");
        require(block.chainid == a.sourceChainIdMain, "wrong source chain");
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = vm.envOr("DEPOSIT_CAP", a.defaultCap);
        address endpoint = A.endpoint(block.chainid);
        vm.startBroadcast();
        LeafOFTAdapter adapter =
            new LeafOFTAdapter(a.innerMainnet, endpoint, owner, guardian, feeRecipient, cap);
        console2.log("ASSET", id);
        console2.log("inner", a.innerMainnet);
        console2.log("LeafOFTAdapter", address(adapter));
        vm.stopBroadcast();
    }
}
