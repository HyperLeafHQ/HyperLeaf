// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafNftLockbox} from "src/lz/LeafNftLockbox.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LeafVePolicy} from "src/lz/LeafVePolicy.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice hveAERO only. Not a MainnetBatches id — grok bot must not run this
///         until a dedicated canary of this box exists (see GROK_BOT_MAINNET
///         "Still not this job"). DeployClosed will revert ASSET=hveaero.
contract DeployNftLockbox is Script {
    function run() external {
        string memory id = vm.envString("ASSET");
        require(keccak256(bytes(id)) == keccak256("hveaero"), "only hveaero");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        require(a.kind == AssetCatalog.Kind.Closed, "not C1");
        require(a.innerMainnet == LeafVePolicy.VE, "not veAERO");
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = vm.envOr("DEPOSIT_CAP", a.defaultCap);

        vm.startBroadcast();
        if (block.chainid == 8453) {
            LeafNftLockbox box = new LeafNftLockbox(
                LeafVePolicy.VE, A.endpoint(8453), owner, guardian, feeRecipient, cap
            );
            console2.log("ASSET", id);
            console2.log("LeafNftLockbox", address(box));
            console2.log("ve", LeafVePolicy.VE);
        } else if (block.chainid == 999) {
            LeafClosedOFT oft = new LeafClosedOFT(a.name, a.symbol, 0, A.ENDPOINT_HYPEREVM, owner, guardian);
            console2.log("ASSET", id);
            console2.log("LeafClosedOFT", address(oft));
            console2.log("lockSeconds 0 = permanent");
        } else {
            revert("hveAERO is Base 8453 source / HyperEVM dest");
        }
        vm.stopBroadcast();
    }
}
