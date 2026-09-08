// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {HypeAddresses as H} from "src/lz/HypeAddresses.sol";
import {LeafOrderPolicy} from "src/lz/LeafOrderPolicy.sol";
import {IBluaiStake} from "src/lz/IBluaiStake.sol";

/// @notice C1 source after DeployClosed + WirePeers. BATCH=4. Not for L adapters.
///         Pins farm for BLUAI4Y / hORDER. Does not `setShareExit` / `setRedeemEnabled`.
contract ConfigureClosedListing is Script {
    function run() external {
        address source = vm.envAddress("SOURCE");
        address harvester = vm.envAddress("HARVESTER");
        address converter = vm.envAddress("CONVERTER");
        address owner = vm.envAddress("OWNER");
        require(harvester != owner && converter != owner, "split keys");

        string memory id = vm.envString("ASSET");
        uint8 batch = uint8(vm.envOr("BATCH", uint256(4)));
        MainnetBatches.requireBatch(id, batch);
        require(batch == MainnetBatches.CLOSED, "not C1 batch");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(a.kind == AssetCatalog.Kind.Closed, "not C1");

        vm.startBroadcast();
        LeafInboundLockbox box = LeafInboundLockbox(source);
        require(address(box.innerToken()) == a.innerMainnet, "inner != catalog");
        box.setConvertYieldToHype(true);
        box.setHarvester(harvester);
        box.setConverter(converter);

        if (keccak256(bytes(id)) == keccak256("horder")) {
            LeafOrderPolicy.requireArbOrder(address(box.innerToken()), block.chainid);
            box.setFarm(LeafOrderPolicy.ORDERLY_PROXY, LeafOrderPolicy.STAKE_ORDER, 0, bytes4(0));
            box.setFarmStyle(LeafInboundLockbox.FarmStyle.AmountNative, 0);
            box.setFarmRequest(LeafOrderPolicy.SEND_REQUEST);
            box.setPublicRequestType(LeafOrderPolicy.TYPE_HARVEST_USDC, true);
            box.setPublicRequestType(LeafOrderPolicy.TYPE_OCCUPANCY, true);
        } else if (keccak256(bytes(id)) == keccak256("bluai4y")) {
            require(block.chainid == 56, "BLUAI is BSC");
            box.setFarm(H.BLUAI_STAKE_BSC, IBluaiStake.stake.selector, 4, IBluaiStake.claimAll.selector);
            box.setFarmExit(IBluaiStake.unstake.selector);
            box.setFarmStyle(LeafInboundLockbox.FarmStyle.AmountYears, 0);
        }

        vm.stopBroadcast();

        console2.log("configured C1", source);
        console2.log("ASSET", a.id);
        console2.log("farm", box.farm());
        console2.log("farmStyle", uint256(box.farmStyle()));
        console2.log("redeem stays closed on dest OFT");
        console2.log("do not setShareExit");
    }
}
