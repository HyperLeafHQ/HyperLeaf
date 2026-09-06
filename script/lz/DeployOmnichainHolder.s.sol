// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {LeafOmnichainHolder} from "src/lz/LeafOmnichainHolder.sol";

/// @notice CREATE2 the twin on any EVM with Arachnid factory.
///         Same owner + salt → same address. Deploy on Base first (home), then
///         BSC/ETH/Arb when an eco claim appears. Owner must be a Safe that
///         already exists at the same address on those chains, or an EOA.
contract DeployOmnichainHolder is Script {
    address constant FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    bytes32 constant SALT = keccak256("HyperLeaf.LeafOmnichainHolder.v1");

    function run() external {
        address owner_ = vm.envAddress("OWNER");
        bytes memory initCode = abi.encodePacked(type(LeafOmnichainHolder).creationCode, abi.encode(owner_));
        address predicted = vm.computeCreate2Address(SALT, keccak256(initCode), FACTORY);
        console.log("predicted holder", predicted);

        vm.startBroadcast();
        (bool ok, bytes memory ret) = FACTORY.call(abi.encodePacked(SALT, initCode));
        require(ok, "create2 failed — factory missing on this chain?");
        address deployed;
        if (ret.length == 20) {
            deployed = address(uint160(bytes20(ret)));
        } else if (ret.length == 32) {
            deployed = address(uint256(bytes32(ret)));
        } else {
            deployed = predicted;
        }
        console.log("deployed", deployed);
        vm.stopBroadcast();
    }
}
