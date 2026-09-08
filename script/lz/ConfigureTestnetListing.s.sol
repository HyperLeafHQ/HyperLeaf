// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {TestnetListings} from "src/lz/TestnetListings.sol";

/// @notice Source-chain owner ops after DeployTestnetSource + WirePeers.
///         HARVESTER and CONVERTER must not be OWNER.
///         CONVERTER is LeafYieldConverter, never an EOA.
contract ConfigureTestnetListing is Script {
    bytes4 internal constant QUID_REWARDS = 0x9a99b4f0;

    function run() external {
        address source = vm.envAddress("SOURCE");
        address harvester = vm.envAddress("HARVESTER");
        address converter = vm.envAddress("CONVERTER");
        address owner = vm.envAddress("OWNER");
        require(harvester != owner && converter != owner, "split keys");

        string memory id = vm.envOr("ASSET", string("hxsquid"));
        AssetCatalog.Listing memory a = TestnetListings.get(id);

        vm.startBroadcast();
        LeafOFTAdapter box = LeafOFTAdapter(source);
        box.setConvertYieldToHype(true);
        box.setHarvester(harvester);
        box.setConverter(converter);
        if (keccak256(bytes(a.id)) == keccak256("hxsquid") || keccak256(bytes(a.id)) == keccak256("havnt")) {
            box.setRewardsSelector(QUID_REWARDS);
        }
        if (keccak256(bytes(a.id)) == keccak256("hcbeth")) {
            box.setRateKind(LeafYieldFee.RateKind.ExchangeRate);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hgsoon") || keccak256(bytes(a.id)) == keccak256("hstkwausdc")) {
            box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hsavax")) {
            box.setRateKind(LeafYieldFee.RateKind.GetPooledAvaxByShares);
            box.setRetainRateYield(true);
        }
        if (keccak256(bytes(a.id)) == keccak256("hstkwausdc")) {
            address controller = vm.envAddress("REWARDS_CONTROLLER");
            require(controller != address(0) && controller != source, "umbrella controller");
            box.setRewardsTarget(controller);
            box.setRewardsSelector(bytes4(0xbb492bf5));
        }
        vm.stopBroadcast();

        console2.log("configured", source);
        console2.log("harvester", harvester);
        console2.log("converter", converter);
        console2.log("ASSET", a.id);
    }
}
