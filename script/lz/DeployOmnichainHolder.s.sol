// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {LeafCreate2} from "src/lz/LeafCreate2.sol";
import {LeafOmnichainHolder} from "src/lz/LeafOmnichainHolder.sol";

/// @notice CREATE2 the twin on any EVM with Arachnid factory.
///         Same owner + salt → same address. Deploy on Base first (home), then
///         BSC/ETH/Arb when an eco claim appears. Owner must be a Safe that
///         already exists at the same address on those chains, or an EOA.
contract DeployOmnichainHolder is Script {
    function run() external {
        address owner_ = vm.envAddress("OWNER");
        bytes memory initCode = abi.encodePacked(type(LeafOmnichainHolder).creationCode, abi.encode(owner_));
        address predicted = LeafCreate2.predict(LeafCreate2.HOLDER_SALT, initCode);
        console.log("predicted holder", predicted);

        vm.startBroadcast();
        (bool ok, bytes memory ret) = LeafCreate2.FACTORY.call(abi.encodePacked(LeafCreate2.HOLDER_SALT, initCode));
        require(ok, "create2 failed");
        address deployed;
        if (ret.length == 20) {
            deployed = address(uint160(bytes20(ret)));
        } else if (ret.length == 32) {
            deployed = address(uint160(uint256(bytes32(ret))));
        } else {
            deployed = predicted;
        }
        console.log("deployed", deployed);
        vm.stopBroadcast();
    }
}
