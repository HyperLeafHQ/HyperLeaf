// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";

import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LeafLbtcPolicy} from "src/lz/LeafLbtcPolicy.sol";
import {LeafSpolPolicy} from "src/lz/LeafSpolPolicy.sol";
import {LeafHbarxPolicy} from "src/lz/LeafHbarxPolicy.sol";
import {LeafSghoPolicy} from "src/lz/LeafSghoPolicy.sol";
import {LeafSusdfPolicy} from "src/lz/LeafSusdfPolicy.sol";
import {LeafSffPolicy} from "src/lz/LeafSffPolicy.sol";

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
            LeafLbtcPolicy.requireLbtc(address(box.innerToken()));
            require(IERC20Metadata(address(box.innerToken())).decimals() == LeafLbtcPolicy.INNER_DECIMALS, "not 8-dec");
            require(box.rewardsSelector() == bytes4(0), "lbtc poke");
            box.setRewardsTarget(LeafLbtcPolicy.ASSET_ROUTER);
            box.setShareScale(LeafLbtcPolicy.SHARE_SCALE);
            box.setMaxRateJumpBps(LeafLbtcPolicy.MAX_RATE_JUMP_BPS);
            box.setRateKind(LeafYieldFee.RateKind.RouterGetRate);
            box.setRetainRateYield(true);
            require(box.shareScale() == LeafLbtcPolicy.SHARE_SCALE, "scale");
            require(box.maxRateJumpBps() == LeafLbtcPolicy.MAX_RATE_JUMP_BPS, "jump");
            require(box.rewardsSelector() == bytes4(0), "lbtc poke after");
        }
        if (keccak256(bytes(a.id)) == keccak256("hhbarx")) {
            LeafHbarxPolicy.requireHbarx(address(box.innerToken()));
            require(IERC20Metadata(address(box.innerToken())).decimals() == LeafHbarxPolicy.INNER_DECIMALS, "not 8-dec");
            require(box.rewardsSelector() == bytes4(0), "hbarx poke");
            box.setShareScale(LeafHbarxPolicy.SHARE_SCALE);
            require(box.shareScale() == LeafHbarxPolicy.SHARE_SCALE, "scale");
        }
        if (keccak256(bytes(a.id)) == keccak256("hsgho")) {
            LeafSghoPolicy.requireSgho(address(box.innerToken()));
            require(address(box.innerToken()) != LeafSghoPolicy.GHO, "gho");
            require(box.rewardsSelector() == bytes4(0), "sgho poke");
            box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hsusdf")) {
            LeafSusdfPolicy.requireSusdf(address(box.innerToken()));
            require(address(box.innerToken()) != LeafSusdfPolicy.USDF, "usdf");
            require(box.rewardsSelector() == bytes4(0), "susdf poke");
            box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hsff")) {
            LeafSffPolicy.requireSff(address(box.innerToken()));
            require(address(box.innerToken()) != LeafSffPolicy.FF, "ff");
            require(address(box.innerToken()) != LeafSffPolicy.PRIME, "prime");
            require(box.rewardsSelector() == bytes4(0), "sff poke");
            box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hspol")) {
            LeafSpolPolicy.requireSpol(address(box.innerToken()));
            require(box.rewardsSelector() == bytes4(0), "spol poke");
            box.setRewardsTarget(LeafSpolPolicy.CONTROLLER);
            box.setMaxRateJumpBps(LeafSpolPolicy.MAX_RATE_JUMP_BPS);
            box.setRateKind(LeafYieldFee.RateKind.ConvertSpolToPol);
            box.setRetainRateYield(true);
            require(box.rewardsTarget() == LeafSpolPolicy.CONTROLLER, "spol ctrl");
            require(box.rewardsSelector() == bytes4(0), "spol poke after");
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
