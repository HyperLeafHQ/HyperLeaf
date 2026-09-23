// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafSecurity} from "src/lz/LeafSecurity.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice Mainnet 2-of-3 Labs + Horizen + Canary. Skip on testnet.
///         Send ULN confirmations = this chain. Receive ULN confirmations =
///         the remote chain (source depth of inbound messages). Copying the
///         local number onto both libs is a DVN mismatch.
///         HyperEVM: ASSET sets remote eid (hgsoon/hslisbnb→BSC, hsibera→Bera, hink→Ink, hsteakusdg→Robinhood, default Base).
///         Parked listings (`productionEvm=false`) revert unless PARKED_MAINT=true.
contract SetSecurityStack is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        uint256 chainId = block.chainid;
        address hyperleafDvn = vm.envOr("HYPERLEAF_DVN", address(0));
        string memory id = vm.envOr("ASSET", string(""));
        if (bytes(id).length != 0) {
            AssetCatalog.Listing memory listed = AssetCatalog.requireHere(id);
            require(listed.productionEvm || vm.envOr("PARKED_MAINT", false), "not production evm");
        }

        uint32 remoteEid;
        if (chainId == 999) {
            if (bytes(id).length != 0) {
                remoteEid = AssetCatalog.get(id).sourceEidMain;
            } else {
                uint256 remote = vm.envOr("REMOTE_EID", uint256(0));
                require(remote != 0, "set ASSET or REMOTE_EID on HyperEVM");
                remoteEid = uint32(remote);
            }
        } else {
            remoteEid = A.EID_HYPEREVM;
        }

        LeafSecurity.Pathway memory path = LeafSecurity.pathway(chainId);
        uint64 sendConfirms = A.confirmationsForEid(A.eidForChainId(chainId));
        uint64 recvConfirms = A.confirmationsForEid(remoteEid);

        SetConfigParam[] memory sendParams =
            LeafSecurity.paramsForPathway(remoteEid, sendConfirms, hyperleafDvn, path.optionalDvns, path.executor);
        SetConfigParam[] memory recvParams =
            LeafSecurity.receiveParamsForPathway(remoteEid, recvConfirms, hyperleafDvn, path.optionalDvns);

        vm.startBroadcast();
        LeafOApp(oapp).setEndpointConfig(path.sendLib, sendParams);
        LeafOApp(oapp).setEndpointConfig(path.receiveLib, recvParams);
        vm.stopBroadcast();
        console2.log("security set on", oapp);
        console2.log("remoteEid", remoteEid);
        console2.log("sendConfirms", sendConfirms);
        console2.log("recvConfirms", recvConfirms);
        console2.log("hyperleaf veto dvn", hyperleafDvn);
    }
}
