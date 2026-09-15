// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafPtsMaxLockbox} from "src/lz/LeafPtsMaxLockbox.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LeafPtsMaxPolicy as P} from "src/lz/LeafPtsMaxPolicy.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice PTSMAX only. Not a MainnetBatches id. Do not run until merkle leaf is proven.
///         Merkle stays off. Dest redeem stays closed.
contract DeployPtsMax is Script {
    function run() external {
        string memory id = vm.envString("ASSET");
        require(keccak256(bytes(id)) == keccak256("ptsmax"), "only ptsmax");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(a.kind == AssetCatalog.Kind.Closed, "not C1");
        require(!a.productionEvm, "not production until merkle leaf");
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = vm.envOr("DEPOSIT_CAP", a.defaultCap);

        vm.startBroadcast();
        if (block.chainid == 56) {
            P.requireBsc(block.chainid);
            P.requireLive(P.PTS, P.CONVERT, P.SRIVER_V2);
            LeafPtsMaxLockbox box = new LeafPtsMaxLockbox(
                P.PTS, P.CONVERT, P.SRIVER_V2, A.endpoint(56), owner, guardian, feeRecipient, cap
            );
            console2.log("ASSET", id);
            console2.log("LeafPtsMaxLockbox", address(box));
            console2.log("do not setMerkleEnabled");
        } else if (block.chainid == 999) {
            LeafClosedOFT oft = new LeafClosedOFT(a.name, a.symbol, 0, A.ENDPOINT_HYPEREVM, owner, guardian);
            console2.log("ASSET", id);
            console2.log("LeafClosedOFT", address(oft));
            console2.log("redeem stays closed; unlockAt", P.UNLOCK_AT);
        } else {
            revert("PTSMAX is BSC 56 source / HyperEVM dest");
        }
        vm.stopBroadcast();
    }
}
