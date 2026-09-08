// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {TestnetListings} from "src/lz/TestnetListings.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice HyperEVM testnet (998) half. Run after DeployTestnetSource.
contract DeployTestnetDest is Script {
    function run() external {
        string memory id = vm.envString("ASSET");
        AssetCatalog.Listing memory a = TestnetListings.get(id);
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(block.chainid == 998, "run on HyperEVM testnet 998");
        require(owner != guardian, "OWNER == GUARDIAN");
        address endpoint = A.ENDPOINT_HYPEREVM_TESTNET;

        vm.startBroadcast();
        address oft;
        if (a.kind == AssetCatalog.Kind.Closed) {
            oft = address(new LeafClosedOFT(a.name, a.symbol, a.lockSeconds, endpoint, owner, guardian));
            console2.log("LeafClosedOFT", oft);
            console2.log("redeemEnabled", LeafClosedOFT(oft).redeemEnabled());
        } else {
            oft = address(new LeafOFT(a.name, a.symbol, endpoint, owner, guardian));
            console2.log("LeafOFT", oft);
        }

        vm.stopBroadcast();

        console2.log("ASSET", id);
        console2.log("symbol", a.symbol);
        console2.log("OFT", oft);
        console2.log("next: SOURCE_OAPP=<src> DEST_OAPP=<oft> REMOTE_EID=40362/40245 forge script WirePeers");
    }
}
