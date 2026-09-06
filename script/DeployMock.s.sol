// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {HNest} from "../src/HNest.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockVotingEscrow} from "../test/mocks/MockVotingEscrow.sol";
import {MockHevAdapter} from "../test/mocks/MockHevAdapter.sol";

/**
 * @title DeployMock
 * @notice HyperEVM TESTNET (chainId 998) mock deps for frontend / pause drill.
 *         NOT mainnet. NOT real Nest HEV.
 *
 * HyperEVM block gasLimit = 3_000_000:
 * - This script deploys Mock NEST/HYPE/ve/adapter + HNest (CREATE-address predicted for vault).
 * - NestVault MUST be deployed in a separate raw creation tx, e.g.:
 *     forge create src/NestVault.sol:NestVault --gas-limit 3000000 --broadcast \
 *       --constructor-args <NEST> <VE> <HYPE> <ADAPTER> <fee> <keeper> <guardian> <cap> <HNEST>
 *   (requires foundry via_ir + optimizer_runs=1 so NestVault create gas ~2.59M fits).
 * - Then: adapter.setVault(vault); nest.mint(deployer, amount).
 *
 * Roles for drill: guardian=keeper=feeRecipient=deployer EOA.
 * Production guardian MUST be user multisig.
 */
contract DeployMock is Script {
    uint256 public constant DEPOSIT_CAP = 1_000_000 ether;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        require(block.chainid == 998, "DeployMock: expected HyperEVM testnet chainId 998");

        // Order: NEST, HYPE, ve, adapter, HNest => next nonce is NestVault
        uint64 n0 = vm.getNonce(deployer);
        address predictedVault = vm.computeCreateAddress(deployer, n0 + 5);

        vm.startBroadcast(pk);
        MockERC20 nest = new MockERC20("Mock NEST", "mNEST");
        MockERC20 hype = new MockERC20("Mock HYPE", "mHYPE");
        MockVotingEscrow ve = new MockVotingEscrow(address(nest));
        MockHevAdapter adapter = new MockHevAdapter(address(ve), address(hype), address(0));
        HNest hNest = new HNest(predictedVault);
        vm.stopBroadcast();

        console2.log("MOCK_DEPLOY_NOTE production guardian must be user multisig");
        console2.log("NEST", address(nest));
        console2.log("HYPE", address(hype));
        console2.log("MockVotingEscrow", address(ve));
        console2.log("MockHevAdapter", address(adapter));
        console2.log("HNest", address(hNest));
        console2.log("predicted NestVault (next nonce)", predictedVault);
        console2.log("depositCap", DEPOSIT_CAP);
        console2.log("guardian_keeper_fee", deployer);
        console2.log("chainId", block.chainid);
        console2.log("NEXT forge create NestVault with _hNest=HNest gas-limit 3000000");
    }
}
