// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafB3Lockbox} from "src/lz/LeafB3Lockbox.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LeafB3Policy as P} from "src/lz/LeafB3Policy.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice hB3 only. Not a MainnetBatches id. Do not run until WIN/claim tx is pinned.
contract DeployB3 is Script {
    function run() external {
        string memory id = vm.envString("ASSET");
        require(keccak256(bytes(id)) == keccak256("hb3"), "only hb3");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(a.kind == AssetCatalog.Kind.Closed, "not C1");
        require(!a.productionEvm, "not production until claim tx");
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = vm.envOr("DEPOSIT_CAP", a.defaultCap);

        vm.startBroadcast();
        if (block.chainid == 8453) {
            P.requireBase(block.chainid);
            P.requireLive(P.B3, P.STAKE);
            LeafB3Lockbox box = new LeafB3Lockbox(
                P.B3, P.STAKE, P.CUSTODY, A.endpoint(8453), owner, guardian, feeRecipient, cap
            );
            console2.log("ASSET", id);
            console2.log("LeafB3Lockbox", address(box));
            console2.log("claim stays 0 — WIN not claimable yet");
        } else if (block.chainid == 999) {
            LeafClosedOFT oft = new LeafClosedOFT(a.name, a.symbol, 0, A.ENDPOINT_HYPEREVM, owner, guardian);
            console2.log("ASSET", id);
            console2.log("LeafClosedOFT", address(oft));
        } else {
            revert("hB3 is Base 8453 source / HyperEVM dest");
        }
        vm.stopBroadcast();
    }
}
