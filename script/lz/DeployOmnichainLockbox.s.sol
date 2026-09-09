// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {LeafCreate2} from "src/lz/LeafCreate2.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice CREATE2 C1 lockbox. Same owner/guardian/fee/cap/inner/endpoint
///         initcode → same address on Arb and Base (Orderly address-keyed ledger).
contract DeployOmnichainLockbox is Script {
    function run() external {
        address owner_ = vm.envAddress("OWNER");
        address guardian_ = vm.envAddress("GUARDIAN");
        address feeRecipient_ = vm.envOr("FEE_RECIPIENT", owner_);
        uint256 cap = vm.envOr("DEPOSIT_CAP", uint256(1_000e18));
        address inner = vm.envAddress("INNER_TOKEN");
        address endpoint_ = A.endpoint(block.chainid);

        bytes memory initCode = abi.encodePacked(
            type(LeafInboundLockbox).creationCode,
            abi.encode(inner, endpoint_, owner_, guardian_, feeRecipient_, cap)
        );
        address predicted = LeafCreate2.predict(LeafCreate2.LOCKBOX_SALT, initCode);
        console.log("predicted lockbox", predicted);

        vm.startBroadcast();
        (bool ok,) = LeafCreate2.FACTORY.call(abi.encodePacked(LeafCreate2.LOCKBOX_SALT, initCode));
        require(ok, "create2 failed");
        vm.stopBroadcast();
        console.log("chain", block.chainid);
    }
}
