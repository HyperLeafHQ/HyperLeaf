// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

contract DeployClosed is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = vm.envOr("DEPOSIT_CAP", uint256(1_000e18));
        uint256 chainId = block.chainid;

        vm.startBroadcast();
        if (chainId == 56 || chainId == 97) {
            address inner = vm.envAddress("INNER_TOKEN");
            LeafInboundLockbox box =
                new LeafInboundLockbox(inner, A.ENDPOINT_BSC, owner, guardian, feeRecipient, cap);
            console2.log("LeafInboundLockbox", address(box));
        } else if (chainId == 999 || chainId == 998) {
            string memory name = vm.envOr("OFT_NAME", string("Hyperliquid BLUAI 4Year"));
            string memory symbol = vm.envOr("OFT_SYMBOL", string("BLUAI4Y"));
            uint32 lockSeconds = uint32(vm.envOr("LOCK_SECONDS", uint256(A.LOCK_4Y)));
            address endpoint = chainId == 999 ? A.ENDPOINT_HYPEREVM : A.ENDPOINT_HYPEREVM_TESTNET;
            LeafClosedOFT oft = new LeafClosedOFT(name, symbol, lockSeconds, endpoint, owner, guardian);
            console2.log("LeafClosedOFT", address(oft));
        } else if (chainId == 8453) {
            address inner = vm.envAddress("INNER_TOKEN");
            LeafInboundLockbox box =
                new LeafInboundLockbox(inner, A.ENDPOINT_BASE, owner, guardian, feeRecipient, cap);
            console2.log("LeafInboundLockbox", address(box));
        } else {
            revert("unsupported chain");
        }
        vm.stopBroadcast();
    }
}
