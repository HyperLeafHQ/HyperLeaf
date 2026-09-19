// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {LeafVirtualsLockbox} from "src/lz/LeafVirtualsLockbox.sol";
import {LeafCreate2} from "src/lz/LeafCreate2.sol";
import {LeafVirtualsPolicy} from "src/lz/LeafVirtualsPolicy.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice CREATE2 hVIRTUALMAX lockbox. Same initcode on canonical-endpoint
///         EVMs so agent merkle `account` matches. Extra-chain twin: do NOT
///         openBridge. RH endpoint is Bera CREATE2 — address will not match;
///         skip RH dust. No GO.
contract DeployOmnichainVirtuals is Script {
    function run() external {
        address owner_ = vm.envAddress("OWNER");
        address guardian_ = vm.envAddress("GUARDIAN");
        address feeRecipient_ = vm.envOr("FEE_RECIPIENT", owner_);
        uint256 cap = vm.envOr("DEPOSIT_CAP", uint256(0));
        address inner = vm.envOr("INNER_TOKEN", LeafVirtualsPolicy.VIRTUAL);
        address virtuals_ = vm.envOr("VIRTUALS_STAKE", LeafVirtualsPolicy.STAKE);
        address endpoint_ = A.endpoint(block.chainid);

        bytes memory initCode = abi.encodePacked(
            type(LeafVirtualsLockbox).creationCode,
            abi.encode(inner, virtuals_, endpoint_, owner_, guardian_, feeRecipient_, cap)
        );
        address predicted = LeafCreate2.predict(LeafCreate2.VIRTUALS_SALT, initCode);
        console.log("predicted virtuals lockbox", predicted);
        console.log("chain", block.chainid);

        vm.startBroadcast();
        (bool ok,) = LeafCreate2.FACTORY.call(abi.encodePacked(LeafCreate2.VIRTUALS_SALT, initCode));
        require(ok, "create2 failed");
        vm.stopBroadcast();
    }
}
