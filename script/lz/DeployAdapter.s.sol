// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";

/// @notice Mainnet L source. BATCH=1|2|3. Never canary, never a mock inner.
///         Broadcast on the listing's sourceChainIdMain.
contract DeployAdapter is Script {
    function run() external {
        string memory id = vm.envString("ASSET");
        uint8 batch = uint8(vm.envOr("BATCH", uint256(1)));
        MainnetBatches.requireBatch(id, batch);
        require(batch != MainnetBatches.CANARY, "use DeployCanarySource");
        require(batch != MainnetBatches.CLOSED, "C1: DeployClosed");
        require(batch != MainnetBatches.SOLANA_L, "Solana: not LeafOFTAdapter");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(a.kind == AssetCatalog.Kind.Liquid, "not L");
        require(a.productionEvm, "not production evm");
        require(block.chainid == a.sourceChainIdMain, "wrong source chain");
        require(a.innerMainnet != address(0), "no inner");
        uint8 decimals = IERC20Metadata(a.innerMainnet).decimals();
        uint256 explicitCap = vm.envOr("DEPOSIT_CAP", uint256(0));
        if (decimals != 18) {
            require(explicitCap != 0, "DEPOSIT_CAP required for non-18-decimal asset");
        }
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = explicitCap != 0 ? explicitCap : a.defaultCap;
        require(cap != 0, "zero deposit cap");
        vm.startBroadcast();
        LeafOFTAdapter adapter =
            new LeafOFTAdapter(a.innerMainnet, endpoint(block.chainid), owner, guardian, feeRecipient, cap);
        console2.log("ASSET", id);
        console2.log("inner", a.innerMainnet);
        console2.log("decimals", decimals);
        console2.log("cap (raw units)", cap);
        console2.log("LeafOFTAdapter", address(adapter));
        vm.stopBroadcast();
    }

    function endpoint(uint256 chainId) internal pure returns (address) {
        return A.endpoint(chainId);
    }
}
