// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {LeafVirtualsLockbox} from "src/lz/LeafVirtualsLockbox.sol";
import {LeafRedeemQueue} from "src/lz/LeafRedeemQueue.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {HypeAddresses} from "src/lz/HypeAddresses.sol";

/// @notice Source-chain half of a testnet wrap.
///         ASSET=hkaito|hxsquid|hcbeth|hwsteth|hsavax|hvirtualmax|bluai4y|bonk12m|hmet|hshmon
///         INNER_TOKEN unset → deploys a mintable mock (always, on testnet).
contract DeployTestnetSource is Script {
    function run() external {
        string memory id = vm.envString("ASSET");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = vm.envOr("DEPOSIT_CAP", a.defaultCap);
        address endpoint = A.endpoint(block.chainid);

        vm.startBroadcast();
        address inner = vm.envOr("INNER_TOKEN", address(0));
        if (inner == address(0)) {
            MockERC20 mock = new MockERC20(a.innerSymbol, a.innerSymbol);
            mock.mint(owner, 1_000_000 ether);
            inner = address(mock);
            console2.log("MockInner", inner);
        }

        address source;
        if (a.kind == AssetCatalog.Kind.Liquid) {
            source = address(new LeafOFTAdapter(inner, endpoint, owner, guardian, feeRecipient, cap));
            console2.log("LeafOFTAdapter", source);
        } else if (a.kind == AssetCatalog.Kind.Closed) {
            if (keccak256(bytes(a.id)) == keccak256("hvirtualmax") && block.chainid == 8453) {
                address stake = vm.envOr("VIRTUALS_STAKE", HypeAddresses.VIRTUALS_STAKE_BASE);
                source = address(
                    new LeafVirtualsLockbox(inner, stake, endpoint, owner, guardian, feeRecipient, cap)
                );
                console2.log("LeafVirtualsLockbox", source);
                console2.log("virtualsStake", stake);
            } else {
                source = address(new LeafInboundLockbox(inner, endpoint, owner, guardian, feeRecipient, cap));
                console2.log("LeafInboundLockbox", source);
            }
        } else {
            source = address(new LeafRedeemQueue(inner, endpoint, owner, guardian, feeRecipient, cap, a.redeemDelay));
            console2.log("LeafRedeemQueue", source);
        }
        vm.stopBroadcast();

        console2.log("ASSET", id);
        console2.log("kind", uint256(a.kind));
        console2.log("symbol", a.symbol);
        console2.log("sourceEidTest", a.sourceEidTest);
        console2.log("destEidTest", A.EID_HYPEREVM_TESTNET);
    }
}
