// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";

import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LeafLbtcPolicy} from "src/lz/LeafLbtcPolicy.sol";
import {LeafListaPolicy} from "src/lz/LeafListaPolicy.sol";
import {LeafSiberaPolicy} from "src/lz/LeafSiberaPolicy.sol";
import {LeafUmbrellaPolicy} from "src/lz/LeafUmbrellaPolicy.sol";
import {LeafLbtcvPolicy} from "src/lz/LeafLbtcvPolicy.sol";

/// @notice Mainnet L owner ops after DeployAdapter + WirePeers.
///         BATCH must match the listing. HARVESTER and CONVERTER must not be OWNER.
contract ConfigureMainnetListing is Script {
    bytes4 internal constant QUID_REWARDS = 0x9a99b4f0;
    uint16 internal constant RATE_L_JUMP_BPS = 300;

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
        if (keccak256(bytes(a.id)) == keccak256("hquid") || keccak256(bytes(a.id)) == keccak256("havnt")) {
            box.setRewardsSelector(QUID_REWARDS);
        }
        if (keccak256(bytes(a.id)) == keccak256("hswbera") || keccak256(bytes(a.id)) == keccak256("hgsoon")) {
            box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
            box.setRetainRateYield(true);
            box.setMaxRateJumpBps(RATE_L_JUMP_BPS);
            require(box.maxRateJumpBps() == RATE_L_JUMP_BPS, "jump");
        }
        if (keccak256(bytes(a.id)) == keccak256("hsibera")) {
            LeafSiberaPolicy.requireSibera(address(box.innerToken()));
            require(box.rewardsSelector() == bytes4(0), "sibera poke");
            box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
            box.setRetainRateYield(true);
            box.setMaxRateJumpBps(RATE_L_JUMP_BPS);
            require(box.maxRateJumpBps() == RATE_L_JUMP_BPS, "jump");
            require(box.rewardsSelector() == bytes4(0), "sibera poke after");
        }
        if (keccak256(bytes(a.id)) == keccak256("hslisbnb")) {
            LeafListaPolicy.requireSlisBnb(address(box.innerToken()));
            require(box.rewardsSelector() == bytes4(0), "lista poke");
            box.setRewardsTarget(LeafListaPolicy.STAKE_MANAGER);
            box.setRateKind(LeafYieldFee.RateKind.ConvertSnBnbToBnb);
            box.setRetainRateYield(true);
            box.setMaxRateJumpBps(RATE_L_JUMP_BPS);
            require(box.maxRateJumpBps() == RATE_L_JUMP_BPS, "jump");
            require(box.rewardsSelector() == bytes4(0), "lista poke after");
        }
        if (keccak256(bytes(a.id)) == keccak256("hcbeth")) {
            box.setRateKind(LeafYieldFee.RateKind.ExchangeRate);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hsavax")) {
            require(box.rewardsSelector() == bytes4(0), "avax poke");
            box.setRateKind(LeafYieldFee.RateKind.GetPooledAvaxByShares);
            box.setRetainRateYield(true);
            box.setMaxRateJumpBps(RATE_L_JUMP_BPS);
            require(box.maxRateJumpBps() == RATE_L_JUMP_BPS, "jump");
            require(box.rewardsSelector() == bytes4(0), "avax poke after");
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
        if (keccak256(bytes(a.id)) == keccak256("hlbtcv")) {
            LeafLbtcvPolicy.requireLbtcv(address(box.innerToken()));
            require(
                IERC20Metadata(address(box.innerToken())).decimals() == LeafLbtcvPolicy.INNER_DECIMALS, "not 8-dec"
            );
            require(box.rewardsSelector() == bytes4(0), "lbtcv poke");
            box.setRewardsTarget(LeafLbtcvPolicy.ACCOUNTANT);
            box.setRateQuote(LeafLbtcvPolicy.LBTC);
            box.setShareScale(LeafLbtcvPolicy.SHARE_SCALE);
            box.setMaxRateJumpBps(LeafLbtcvPolicy.MAX_RATE_JUMP_BPS);
            box.setRateKind(LeafYieldFee.RateKind.GetRateInQuote);
            box.setRetainRateYield(true);
            require(box.shareScale() == LeafLbtcvPolicy.SHARE_SCALE, "scale");
            require(box.maxRateJumpBps() == LeafLbtcvPolicy.MAX_RATE_JUMP_BPS, "jump");
            require(box.rewardsTarget() == LeafLbtcvPolicy.ACCOUNTANT, "accountant");
            require(box.rateQuote() == LeafLbtcvPolicy.LBTC, "quote");
            require(box.rewardsSelector() == bytes4(0), "lbtcv poke after");
            LeafLbtcvPolicy.requireAccountant(box.rewardsTarget());
            LeafLbtcvPolicy.requireQuote(box.rateQuote());
        }
        if (keccak256(bytes(a.id)) == keccak256("hstkwausdc")) {
            LeafUmbrellaPolicy.requireStkwaUsdc(address(box.innerToken()));
            require(
                IERC20Metadata(address(box.innerToken())).decimals() == LeafUmbrellaPolicy.INNER_DECIMALS, "not 6-dec"
            );
            box.setShareScale(LeafUmbrellaPolicy.SHARE_SCALE);
            box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
            box.setRetainRateYield(true);
            box.setMaxRateJumpBps(RATE_L_JUMP_BPS);
            box.setRewardsTarget(LeafUmbrellaPolicy.REWARDS_CONTROLLER);
            box.setRewardsSelector(LeafUmbrellaPolicy.CLAIM_ALL_REWARDS);
            require(box.shareScale() == LeafUmbrellaPolicy.SHARE_SCALE, "scale");
            require(box.maxRateJumpBps() == LeafUmbrellaPolicy.MAX_RATE_JUMP_BPS, "jump");
            require(box.rewardsTarget() == LeafUmbrellaPolicy.REWARDS_CONTROLLER, "controller");
            require(box.rewardsSelector() == LeafUmbrellaPolicy.CLAIM_ALL_REWARDS, "poke");
            LeafUmbrellaPolicy.requireController(box.rewardsTarget(), address(box.innerToken()));
        }
        vm.stopBroadcast();

        console2.log("configured", source);
        console2.log("ASSET", a.id);
        console2.log("BATCH", batch);
        console2.log("harvester", harvester);
        console2.log("converter", converter);
    }
}
