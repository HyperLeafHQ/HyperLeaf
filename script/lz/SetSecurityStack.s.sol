// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafSecurity} from "src/lz/LeafSecurity.sol";
import {SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

contract SetSecurityStack is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        uint256 chainId = block.chainid;
        address hyperleafDvn = vm.envOr("HYPERLEAF_DVN", address(0));

        uint32 remoteEid;
        address sendLib;
        address receiveLib;
        address executor;
        uint64 confirms;
        address[] memory optionalDvns;

        if (chainId == 8453) {
            remoteEid = A.EID_HYPEREVM;
            sendLib = A.SEND_ULN_BASE;
            receiveLib = A.RECEIVE_ULN_BASE;
            executor = A.EXECUTOR_BASE;
            confirms = A.CONFIRMATIONS_BASE;
            optionalDvns = LeafSecurity.baseOptionalDvns();
        } else if (chainId == 999) {
            remoteEid = A.EID_BASE;
            sendLib = A.SEND_ULN_HYPEREVM;
            receiveLib = A.RECEIVE_ULN_HYPEREVM;
            executor = A.EXECUTOR_HYPEREVM;
            confirms = A.CONFIRMATIONS_HYPEREVM;
            optionalDvns = LeafSecurity.hyperevmOptionalDvns();
        } else {
            revert("unsupported chain");
        }

        SetConfigParam[] memory sendParams =
            LeafSecurity.paramsForPathway(remoteEid, confirms, hyperleafDvn, optionalDvns, executor);
        SetConfigParam[] memory recvParams = new SetConfigParam[](1);
        recvParams[0] = sendParams[0];

        vm.startBroadcast();
        LeafOApp(oapp).setEndpointConfig(sendLib, sendParams);
        LeafOApp(oapp).setEndpointConfig(receiveLib, recvParams);
        vm.stopBroadcast();
        console2.log("security set on", oapp);
        console2.log("hyperleaf veto dvn", hyperleafDvn);
    }
}
