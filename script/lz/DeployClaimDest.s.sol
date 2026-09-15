import {Script, console2} from "forge-std/Script.sol";
import {LeafClaimEscrow} from "src/lz/LeafClaimEscrow.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {HyperEVMAddresses as H} from "src/config/HyperEVMAddresses.sol";

/// @notice HyperEVM mainnet Leaf Market escrow. After the Leaf exists.
///         hNEST: LEAF=hNEST WANT=NEST NEST_VAULT=NestVaultC1 REWARDER unset. Do not deploy Fill.
///         Non-NEST listings: NEST_VAULT must be unset.
contract DeployClaimDest is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address guardian = vm.envAddress("GUARDIAN");
        require(block.chainid == 999, "HyperEVM 999");
        require(owner != guardian, "OWNER == GUARDIAN");
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        address leaf = vm.envAddress("LEAF");
        address want = vm.envAddress("WANT");
        address rewarder = vm.envOr("REWARDER", address(0));
        bytes32 rewardId = vm.envOr("REWARD_ID", bytes32(0));
        address nestVault = vm.envOr("NEST_VAULT", address(0));
        uint32 wantEid = uint32(vm.envOr("WANT_EID", uint256(0)));
        if (want == H.NEST) {
            require(nestVault != address(0), "NEST market requires NEST_VAULT");
            require(wantEid == 0, "NEST is fillLocal");
        } else {
            require(nestVault == address(0), "NEST_VAULT only for NEST market");
        }

        vm.startBroadcast();
        LeafClaimEscrow escrow = new LeafClaimEscrow(A.ENDPOINT_HYPEREVM, owner, guardian, feeRecipient);
        if (wantEid == 0) {
            escrow.setMarket(leaf, want, rewardId, true);
        } else {
            escrow.setRemoteMarket(leaf, want, rewardId, true, wantEid);
        }
        if (rewarder != address(0)) escrow.setRewarder(rewarder);
        if (nestVault != address(0)) escrow.setNestHypeVault(leaf, nestVault);
        vm.stopBroadcast();

        console2.log("LeafClaimEscrow", address(escrow));
        console2.log("LEAF", leaf);
        console2.log("WANT", want);
        console2.log("WANT_EID", wantEid);
        if (nestVault != address(0)) console2.log("nestHypeVault", nestVault);
        console2.log("next: deploy Fill on source, then WirePeers OAPP=escrow PEER=fill ASSET=...");
    }
}