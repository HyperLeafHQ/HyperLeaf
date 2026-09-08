// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafClaimFill} from "src/lz/LeafClaimFill.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice Source-chain fill box (batch 4). WANT = inner.
contract DeployClaimSource is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        require(_isSource(block.chainid), "not a claim source chain");
        address want = vm.envAddress("WANT");
        uint256 returnNative_ = vm.envOr("RETURN_NATIVE", uint256(0.01 ether));
        require(returnNative_ <= type(uint128).max, "RETURN_NATIVE");
        uint128 returnNative = uint128(returnNative_);
        address endpoint = A.endpoint(block.chainid);

        vm.startBroadcast();
        LeafClaimFill fill = new LeafClaimFill(endpoint, owner, guardian);
        fill.setInner(want, true);
        fill.setReturnNative(returnNative);
        vm.stopBroadcast();

        console2.log("LeafClaimFill", address(fill));
        console2.log("WANT", want);
        console2.log("RETURN_NATIVE", returnNative);
        console2.log("next: WirePeers both ways. OAPP=fill PEER=escrow ASSET=...");
    }

    function _isSource(uint256 chainId) internal pure returns (bool) {
        return chainId == 8453 || chainId == 56 || chainId == 42161 || chainId == 1 || chainId == 43114
            || chainId == 80094;
    }
}
