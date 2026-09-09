// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafYieldConverter} from "src/lz/LeafYieldConverter.sol";
import {HypeAddresses} from "src/lz/HypeAddresses.sol";

/// @notice Deploy on the source (Base / BSC) AND on HyperEVM.
///         Source: setLockbox + setToken(QUID/USDC/…) + setRoute(DEX/deBridge/Mayan/Relay).
///         HyperEVM: setRewarder(LeafHypeRewarder, WHYPE).
///         OWNER, KEEPER, GUARDIAN must be three different keys.
///         Then source.setConverter(this). Never setConverter to an EOA.
contract DeployYieldConverter is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address keeper = vm.envAddress("KEEPER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != keeper && keeper != guardian && owner != guardian, "split keys");
        vm.startBroadcast();
        LeafYieldConverter c = new LeafYieldConverter(owner, keeper, guardian);
        if (block.chainid == 999 || block.chainid == 998) {
            address rewarder = vm.envAddress("REWARDER");
            c.setRewarder(rewarder, vm.envOr("WHYPE", HypeAddresses.WHYPE));
        }
        vm.stopBroadcast();
        console2.log("LeafYieldConverter", address(c));
        console2.log("chain", block.chainid);
    }
}
