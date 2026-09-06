// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

/**
 * @dev NestVault create exceeds forge-script simulation budget on HyperEVM (3M block gas).
 *      Use forge create instead (see DeployMock header). Addresses from 2026-09-02 drill:
 *        NEST=0x4C862bC0922556e1bF02561bcf6Ff25e43826D5C
 *        HYPE=0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2
 *        VE=0x2101621F51D7E05518D6680C62d04Ad47bC4e05D
 *        ADAPTER=0x4f6615761A772e10d7f802B1C29654ABD90fF30d
 *        HNEST=0xe86961EAF3CD4ED87497641fF32E55875aB7189f
 *        VAULT=0x6f8d22C85e505eCA309635EA552f5067C026A2A9
 */
contract DeployMockResume is Script {
    function run() external pure {
        console2.log("Use forge create for NestVault; see DeployMock.s.sol header + deployments/testnet-998.json");
    }
}
