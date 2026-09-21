// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {NativeOtcFactory} from "../src/premarket/NativeOtcFactory.sol";
import {NativeDeliveryResolver} from "../src/premarket/NativeDeliveryResolver.sol";
import {PremarketAddresses} from "../src/premarket/PremarketAddresses.sol";

/// @notice HyperEVM 999. New factory — do **not** call createMarket on the live VAR factory.
///         Do **not** broadcast until a human comments `GO`.
///         Does not wrap QTC. Does not buy QTC. Collateral is USDM→sUSDM only.
contract DeployNativeOtcQtc is Script {
    function run() external {
        require(block.chainid == PremarketAddresses.HYPEREVM, "HyperEVM 999");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.envOr("OWNER", PremarketAddresses.OWNER);
        address fee = vm.envOr("FEE_RECIPIENT", PremarketAddresses.FEE_RECIPIENT);
        address susdm = PremarketAddresses.SUSDM;

        vm.startBroadcast(pk);
        NativeDeliveryResolver resolver = new NativeDeliveryResolver(owner);
        NativeOtcFactory factory = new NativeOtcFactory(owner, address(resolver), fee, susdm);
        vm.stopBroadcast();

        console2.log("NativeDeliveryResolver", address(resolver));
        console2.log("NativeOtcFactory", address(factory));
        console2.log("vault", address(factory.vault()));
        console2.log("NEXT: owner acceptOwnership on resolver + factory.");
        console2.log("Do not wrap QTC. Do not attest without a Quantus explorer tx.");
    }
}
