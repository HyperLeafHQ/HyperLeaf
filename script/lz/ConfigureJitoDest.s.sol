// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LeafJitoPolicy} from "src/lz/LeafJitoPolicy.sol";

/// @notice HyperEVM dest OFT for hJitoSOL. No Rewarder. No inner ceiling.
///         Peer is set by WireSolanaPeer, not this script.
contract ConfigureJitoDest is Script {
    function run() external {
        string memory id = vm.envOr("ASSET", string("hjitosol"));
        MainnetBatches.requireBatch(id, MainnetBatches.SOLANA_L);
        require(block.chainid == 999, "HyperEVM 999");
        address oftAddr = vm.envAddress("OFT");
        LeafOFT oft = LeafOFT(oftAddr);
        require(address(oft.hypeRewarder()) == address(0), "no rewarder on hJitoSOL");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        uint256 cap = vm.envOr("PEG_CAP", a.defaultCap);
        bool open = vm.envOr("OPEN_BRIDGE", false);

        vm.startBroadcast();
        oft.setListingTag(LeafJitoPolicy.LISTING_TAG);
        oft.setLimits(cap, cap);
        oft.setSupplyCap(cap);
        if (open) oft.openBridge();
        vm.stopBroadcast();

        console2.log("hJitoSOL dest", oftAddr);
        console2.log("cap", cap);
        console2.log("opened", open);
        console2.log("rewarder must stay 0");
        console2.log("next: WireSolanaPeer + SetSecurityStack ASSET=hjitosol");
    }
}
