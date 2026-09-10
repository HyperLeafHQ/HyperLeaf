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
///         HyperEVM: ASSET sets remote eid (hgsoon→BSC, hswbera→Bera, default Base).
contract SetSecurityStack is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        uint256 chainId = block.chainid;
        address hyperleafDvn = vm.envOr("HYPERLEAF_DVN", address(0));
        string memory id = vm.envOr("ASSET", string(""));

        uint32 remoteEid;
        address sendLib;
        address receiveLib;
        address executor;
        address[] memory optionalDvns;

        if (chainId == 8453) {
            remoteEid = A.EID_HYPEREVM;
            sendLib = A.SEND_ULN_BASE;
            receiveLib = A.RECEIVE_ULN_BASE;
            executor = A.EXECUTOR_BASE;
            optionalDvns = LeafSecurity.baseOptionalDvns();
        } else if (chainId == 999) {
            if (bytes(id).length != 0) {
                remoteEid = AssetCatalog.get(id).sourceEidMain;
            } else {
                remoteEid = uint32(vm.envOr("REMOTE_EID", uint256(A.EID_BASE)));
            }
            sendLib = A.SEND_ULN_HYPEREVM;
            receiveLib = A.RECEIVE_ULN_HYPEREVM;
            executor = A.EXECUTOR_HYPEREVM;
            optionalDvns = LeafSecurity.hyperevmOptionalDvns();
        } else if (chainId == 56) {
            remoteEid = A.EID_HYPEREVM;
            sendLib = A.SEND_ULN_BSC;
            receiveLib = A.RECEIVE_ULN_BSC;
            executor = A.EXECUTOR_BSC;
            optionalDvns = LeafSecurity.bscOptionalDvns();
        } else if (chainId == 80094) {
            remoteEid = A.EID_HYPEREVM;
            sendLib = A.SEND_ULN_BERA;
            receiveLib = A.RECEIVE_ULN_BERA;
            executor = A.EXECUTOR_BERA;
            optionalDvns = LeafSecurity.beraOptionalDvns();
        } else if (chainId == 1) {
            remoteEid = A.EID_HYPEREVM;
            sendLib = A.SEND_ULN_ETH;
            receiveLib = A.RECEIVE_ULN_ETH;
            executor = A.EXECUTOR_ETH;
            optionalDvns = LeafSecurity.ethOptionalDvns();
        } else if (chainId == 42161) {
            remoteEid = A.EID_HYPEREVM;
            sendLib = A.SEND_ULN_ARB;
            receiveLib = A.RECEIVE_ULN_ARB;
            executor = A.EXECUTOR_ARB;
            optionalDvns = LeafSecurity.arbOptionalDvns();
        } else if (chainId == 43114) {
            remoteEid = A.EID_HYPEREVM;
            sendLib = A.SEND_ULN_AVAX;
            receiveLib = A.RECEIVE_ULN_AVAX;
            executor = A.EXECUTOR_AVAX;
            optionalDvns = LeafSecurity.avaxOptionalDvns();
        } else if (chainId == 295) {
            remoteEid = A.EID_HYPEREVM;
            sendLib = A.SEND_ULN_HEDERA;
            receiveLib = A.RECEIVE_ULN_HEDERA;
            executor = A.EXECUTOR_HEDERA;
            optionalDvns = LeafSecurity.hederaOptionalDvns();
        } else {
            revert("unsupported chain");
        }

        uint64 sendConfirms = A.confirmationsForEid(A.eidForChainId(chainId));
        uint64 recvConfirms = A.confirmationsForEid(remoteEid);

        SetConfigParam[] memory sendParams =
            LeafSecurity.paramsForPathway(remoteEid, sendConfirms, hyperleafDvn, optionalDvns, executor);
        SetConfigParam[] memory recvParams =
            LeafSecurity.receiveParamsForPathway(remoteEid, recvConfirms, hyperleafDvn, optionalDvns);

        vm.startBroadcast();
        LeafOApp(oapp).setEndpointConfig(sendLib, sendParams);
        LeafOApp(oapp).setEndpointConfig(receiveLib, recvParams);
        vm.stopBroadcast();
        console2.log("security set on", oapp);
        console2.log("remoteEid", remoteEid);
        console2.log("sendConfirms", sendConfirms);
        console2.log("recvConfirms", recvConfirms);
        console2.log("hyperleaf veto dvn", hyperleafDvn);
    }
}
