// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";

import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LeafLbtcPolicy} from "src/lz/LeafLbtcPolicy.sol";

/// @notice Mainnet L owner ops after DeployAdapter + WirePeers.
///         BATCH must match the listing. HARVESTER and CONVERTER must not be OWNER.
contract ConfigureMainnetListing is Script {
    bytes4 internal constant QUID_REWARDS = 0x9a99b4f0;

    function run() external {
        address source = vm.envAddress("SOURCE");
        address harvester = vm.envAddress("HARVESTER");
        address converter = vm.envAddress("CONVERTER");
        address owner = vm.envAddress("OWNER");
        require(harvester != owner && converter != owner, "split keys");

        string memory id = vm.envString("ASSET");
        uint8 batch = uint8(vm.envOr("BATCH", uint256(1)));
        MainnetBatches.requireBatch(id, batch);
        require(batch != MainnetBatches.CLOSED, "C1: ConfigureClosedListing");
        require(batch != MainnetBatches.SOLANA_L, "Solana lockbox is not EVM");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(a.kind == AssetCatalog.Kind.Liquid, "not L");
        require(a.productionEvm, "not production evm");
        if (batch == MainnetBatches.CANARY) {
            require(block.chainid == 8453, "canary is Base");
        } else {
            require(block.chainid == a.sourceChainIdMain, "wrong source chain");
        }

        vm.startBroadcast();
        LeafOFTAdapter box = LeafOFTAdapter(source);
        box.setConvertYieldToHype(true);
        box.setHarvester(harvester);
        box.setConverter(converter);
        if (keccak256(bytes(a.id)) == keccak256("hxsquid") || keccak256(bytes(a.id)) == keccak256("havnt")) {
            box.setRewardsSelector(QUID_REWARDS);
        }
        if (keccak256(bytes(a.id)) == keccak256("hswbera") || keccak256(bytes(a.id)) == keccak256("hgsoon")) {
            box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hcbeth")) {
            box.setRateKind(LeafYieldFee.RateKind.ExchangeRate);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hsavax")) {
            box.setRateKind(LeafYieldFee.RateKind.GetPooledAvaxByShares);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hlbtc")) {
            require(address(box.innerToken()) == LeafLbtcPolicy.LBTC, "not LBTC");
            require(address(box.innerToken()) != LeafLbtcPolicy.BTCB, "BTC.b");
            box.setRewardsTarget(LeafLbtcPolicy.ASSET_ROUTER);
            box.setShareScale(LeafLbtcPolicy.SHARE_SCALE);
            box.setMaxRateJumpBps(LeafLbtcPolicy.MAX_RATE_JUMP_BPS);
            box.setRateKind(LeafYieldFee.RateKind.RouterGetRate);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hstkwausdc")) {
            box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
            box.setRetainRateYield(true);
            address controller = vm.envAddress("REWARDS_CONTROLLER");
            require(controller != address(0) && controller != source, "umbrella controller");
            box.setRewardsTarget(controller);
            box.setRewardsSelector(bytes4(0xbb492bf5));
        }
        vm.stopBroadcast();

        console2.log("configured", source);
        console2.log("ASSET", a.id);
        console2.log("BATCH", batch);
        console2.log("harvester", harvester);
        console2.log("converter", converter);
    }
}
