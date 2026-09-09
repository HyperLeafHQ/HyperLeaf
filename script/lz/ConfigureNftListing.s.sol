// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafNftLockbox} from "src/lz/LeafNftLockbox.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LeafVePolicy} from "src/lz/LeafVePolicy.sol";

/// @notice hveAERO source after DeployNftLockbox + WirePeers. Not a BATCH.
///         Does not vote / merge / split / unlockPermanent. Does not setShareExit.
contract ConfigureNftListing is Script {
    function run() external {
        address source = vm.envAddress("SOURCE");
        address harvester = vm.envAddress("HARVESTER");
        address converter = vm.envAddress("CONVERTER");
        address owner = vm.envAddress("OWNER");
        require(harvester != owner && converter != owner, "split keys");

        string memory id = vm.envString("ASSET");
        require(keccak256(bytes(id)) == keccak256("hveaero"), "only hveaero");
        require(block.chainid == 8453, "veAERO is Base");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(a.kind == AssetCatalog.Kind.Closed, "not C1");
        require(a.innerMainnet == LeafVePolicy.VE, "not veAERO");

        vm.startBroadcast();
        LeafNftLockbox box = LeafNftLockbox(source);
        require(address(box.ve()) == LeafVePolicy.VE, "ve != policy");
        box.setConvertYieldToHype(true);
        box.setHarvester(harvester);
        box.setConverter(converter);
        vm.stopBroadcast();

        console2.log("configured NFT", source);
        console2.log("ASSET", a.id);
        console2.log("ve", address(box.ve()));
        console2.log("do not vote, merge, split, unlockPermanent, or setShareExit");
    }
}
