// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafClaimFill} from "src/lz/LeafClaimFill.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice Source testnet fill box. WANT= inner. RETURN_NATIVE defaults 0.01 ether.
contract DeployClaimSource is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        require(_isTestnet(block.chainid), "not a testnet");
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
        console2.log("next: WirePeers both ways. OAPP=fill PEER=escrow REMOTE_EID=40362");
    }

    function _isTestnet(uint256 chainId) internal pure returns (bool) {
        return chainId == 84532 || chainId == 998 || chainId == 97 || chainId == 43113 || chainId == 80069;
    }
}
