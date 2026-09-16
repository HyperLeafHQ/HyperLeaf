// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PreMarketFactory} from "../src/premarket/PreMarketFactory.sol";
import {PremarketAddresses} from "../src/premarket/PremarketAddresses.sol";

/// @notice HyperEVM 999. Owner-only createMarket for Nado points on the LIVE factory.
///         Do **not** broadcast until a human comments `GO` on the cookbook issue.
///         Does not deploy a factory. Does not wrap INK. Does not resolve.
///
///         Precondition: `factory.marketsCreated() == 2` (VAR n=1, Predict n=2 live).
///         Name / symbol / asset MUST match the frontend pin exactly:
///           createMarket("Nado points", "Nado", sUSDM)
///         Predicted marketId = keccak256(abi.encode("Nado points", sUSDM, 3))
///           = 0x9486988cc36ef76e88b1607554932525fbefc3a2101c4dde123fe67fd22e3bca
contract CreatePremarketNado is Script {
    PreMarketFactory internal constant FACTORY = PreMarketFactory(0x22684F6e63525d009d7cAb9415B0680Fe4aF8f6A);
    bytes32 internal constant EXPECTED_ID =
        0x9486988cc36ef76e88b1607554932525fbefc3a2101c4dde123fe67fd22e3bca;

    function run() external {
        require(block.chainid == PremarketAddresses.HYPEREVM, "HyperEVM 999");
        require(FACTORY.marketsCreated() == 2, "nado is n=3; abort if another market already consumed n=3");
        address collateral = vm.envOr("COLLATERAL", PremarketAddresses.SUSDM);
        require(collateral == PremarketAddresses.SUSDM, "Nado is sUSDM only");
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        bytes32 marketId = FACTORY.createMarket("Nado points", "Nado", collateral);
        vm.stopBroadcast();

        require(marketId == EXPECTED_ID, "marketId != predicted n=3");
        console2.log("Nado marketId");
        console2.logBytes32(marketId);
        console2.log("NEXT: sellers createSeries(marketId, 10000|20000, priceUsd18)");
        console2.log("Do not deploy Ink adapter/OFT. Official INK ERC-20 is not posted.");
    }
}
