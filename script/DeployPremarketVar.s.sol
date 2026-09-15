// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PreMarketFactory} from "../src/premarket/PreMarketFactory.sol";
import {MultisigResolver} from "../src/premarket/MultisigResolver.sol";
import {DeliveryLockbox} from "../src/premarket/DeliveryLockbox.sol";
import {PremarketAddresses} from "../src/premarket/PremarketAddresses.sol";

/// @notice HyperEVM 999. Deploys the VAR canary factory. Does not mint series.
///         Sellers call createSeries themselves (free deal-price, 1x or 2x).
contract DeployPremarketVar is Script {
    function run() external {
        require(block.chainid == PremarketAddresses.HYPEREVM, "HyperEVM 999");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.envOr("OWNER", PremarketAddresses.OWNER);
        address fee = vm.envOr("FEE_RECIPIENT", PremarketAddresses.FEE_RECIPIENT);
        address collateral = vm.envOr("COLLATERAL", PremarketAddresses.SUSDM);
        require(collateral.code.length > 0, "COLLATERAL has no code");
        address susdv = vm.envOr("SUSDV", address(0));

        vm.startBroadcast(pk);
        MultisigResolver resolver = new MultisigResolver(vm.addr(pk));
        PreMarketFactory factory = new PreMarketFactory(vm.addr(pk), address(resolver), fee);
        DeliveryLockbox box = new DeliveryLockbox(vm.addr(pk));
        box.setFactory(address(factory));
        factory.setLockbox(address(box));
        bytes32 marketId = factory.createMarket("Variational points", "Var", collateral);
        if (susdv != address(0)) {
            require(susdv.code.length > 0, "SUSDV has no code");
            bytes32 m2 = factory.createMarket("Variational points sUSDV", "Var", susdv);
            console2.log("VAR sUSDV marketId");
            console2.logBytes32(m2);
        }
        resolver.transferOwnership(owner);
        factory.transferOwnership(owner);
        box.transferOwnership(owner);
        vm.stopBroadcast();

        console2.log("MultisigResolver", address(resolver));
        console2.log("PreMarketFactory", address(factory));
        console2.log("DeliveryLockbox", address(box));
        console2.log("VAR marketId");
        console2.logBytes32(marketId);
        console2.log("collateral", collateral);
        console2.log("pendingOwner", factory.pendingOwner());
        console2.log("NEXT: Owner acceptOwnership on resolver/factory/lockbox");
        console2.log("NEXT: sellers createSeries(marketId, 10000|20000, priceUsd18)");
        console2.log("Do not merge to main until a VAR series has been smoke-filled.");
    }
}
