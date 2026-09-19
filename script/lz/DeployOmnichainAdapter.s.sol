// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafCreate2} from "src/lz/LeafCreate2.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice CREATE2 L adapter. Same initcode on ETH/Base/Arb/BSC (canonical
///         endpoint 0x1a44…). Extra-chain twin is for merkle poke only —
///         do NOT openBridge. Robinhood endpoint differs; RH twin address
///         will not match. No GO.
contract DeployOmnichainAdapter is Script {
    function run() external {
        address owner_ = vm.envAddress("OWNER");
        address guardian_ = vm.envAddress("GUARDIAN");
        address feeRecipient_ = vm.envOr("FEE_RECIPIENT", owner_);
        uint256 cap = vm.envOr("DEPOSIT_CAP", uint256(0));
        address inner = vm.envAddress("INNER_TOKEN");
        address endpoint_ = A.endpoint(block.chainid);

        bytes memory initCode = abi.encodePacked(
            type(LeafOFTAdapter).creationCode,
            abi.encode(inner, endpoint_, owner_, guardian_, feeRecipient_, cap)
        );
        address predicted = LeafCreate2.predict(LeafCreate2.ADAPTER_SALT, initCode);
        console.log("predicted adapter", predicted);
        console.log("chain", block.chainid);
        console.log("endpoint", endpoint_);

        vm.startBroadcast();
        (bool ok,) = LeafCreate2.FACTORY.call(abi.encodePacked(LeafCreate2.ADAPTER_SALT, initCode));
        require(ok, "create2 failed");
        vm.stopBroadcast();
    }
}
