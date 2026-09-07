// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockClaimInner} from "test/mocks/MockClaimInner.sol";
import {MockRateERC20} from "test/mocks/MockRateERC20.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {LeafVirtualsLockbox} from "src/lz/LeafVirtualsLockbox.sol";
import {IBluaiStake} from "src/lz/IBluaiStake.sol";
import {LeafRedeemQueue} from "src/lz/LeafRedeemQueue.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {HypeAddresses} from "src/lz/HypeAddresses.sol";

/// @notice Source-chain half of a testnet wrap.
///         ASSET=hkaito|hxsquid|hcbeth|hwsteth|hsavax|hvirtualmax|bluai4y|bonk12m|hmet|hshmon|hgsoon|hswbera
///         INNER_TOKEN unset → deploys a mintable mock (always, on testnet).
contract DeployTestnetSource is Script {
    function run() external {
        string memory id = vm.envString("ASSET");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(owner != guardian, "OWNER == GUARDIAN");
        require(_isTestnet(block.chainid), "not a testnet");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint256 cap = vm.envOr("DEPOSIT_CAP", a.defaultCap);
        address endpoint = A.endpoint(block.chainid);
        if (a.sourceEidTest == A.EID_BASE_SEPOLIA) {
            require(block.chainid == 84532, "hxsquid/hcbeth source is Base Sepolia 84532");
        }
        if (keccak256(bytes(id)) == keccak256("bluai4y") || keccak256(bytes(id)) == keccak256("hgsoon")) {
            require(block.chainid == 97, "hgsoon/bluai4y source is BSC testnet 97");
        }
        if (keccak256(bytes(id)) == keccak256("hswbera")) {
            require(block.chainid == 80069, "hswbera testnet source is Bepolia 80069, not Base Sepolia");
        }

        vm.startBroadcast();
        address inner = vm.envOr("INNER_TOKEN", address(0));
        if (inner != address(0) && inner == a.innerMainnet) {
            revert("do not point testnet at mainnet inner");
        }
        if (inner == address(0)) {
            if (keccak256(bytes(id)) == keccak256("hxsquid")) {
                MockERC20 quid = new MockERC20("QUID", "QUID");
                MockClaimInner mock = new MockClaimInner(a.innerSymbol, a.innerSymbol, address(quid));
                mock.mint(owner, 1_000_000 ether);
                inner = address(mock);
                console2.log("MockQUID", address(quid));
            } else if (keccak256(bytes(id)) == keccak256("hcbeth")) {
                MockRateERC20 mock = new MockRateERC20(a.innerSymbol, a.innerSymbol);
                mock.mint(owner, 1_000_000 ether);
                inner = address(mock);
            } else {
                MockERC20 mock = new MockERC20(a.innerSymbol, a.innerSymbol);
                mock.mint(owner, 1_000_000 ether);
                inner = address(mock);
            }
            console2.log("MockInner", inner);
        }

        address source;
        if (a.kind == AssetCatalog.Kind.Liquid) {
            source = address(new LeafOFTAdapter(inner, endpoint, owner, guardian, feeRecipient, cap));
            console2.log("LeafOFTAdapter", source);
            if (keccak256(bytes(id)) == keccak256("hxsquid")) {
                LeafOFTAdapter(source).setRewardsSelector(bytes4(0x9a99b4f0));
            }
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
                if (keccak256(bytes(a.id)) == keccak256("bluai4y") && block.chainid == 56) {
                    address stake = vm.envOr("BLUAI_STAKE", HypeAddresses.BLUAI_STAKE_BSC);
                    LeafInboundLockbox(source).setFarm(
                        stake, IBluaiStake.stake.selector, 4, IBluaiStake.claimAll.selector
                    );
                    LeafInboundLockbox(source).setFarmExit(IBluaiStake.unstake.selector);
                    console2.log("bluaiStake", stake);
                }
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

    function _isTestnet(uint256 chainId) internal pure returns (bool) {
        return chainId == 84532 || chainId == 998 || chainId == 97 || chainId == 40161 || chainId == 43113
            || chainId == 80069;
    }
}
