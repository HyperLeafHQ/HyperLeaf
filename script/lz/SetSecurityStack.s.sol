// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafSecurity} from "src/lz/LeafSecurity.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";

/// @notice Mainnet 2-of-3. Skip on testnet.
///         HyperEVM: ASSET sets remote eid (hgsoon→BSC, hswbera→Bera, default Base).
///         BSC/Bera: set DVN0,DVN1,DVN2 from the LZ chain page (Labs+Horizen+Nethermind).
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
            if (bytes(id).length != 0) {
                remoteEid = AssetCatalog.get(id).sourceEidMain;
            } else {
                remoteEid = uint32(vm.envOr("REMOTE_EID", uint256(A.EID_BASE)));
            }
            sendLib = A.SEND_ULN_HYPEREVM;
            receiveLib = A.RECEIVE_ULN_HYPEREVM;
            executor = A.EXECUTOR_HYPEREVM;
            confirms = A.CONFIRMATIONS_HYPEREVM;
            optionalDvns = LeafSecurity.hyperevmOptionalDvns();
        } else if (chainId == 56) {
            remoteEid = A.EID_HYPEREVM;
            sendLib = A.SEND_ULN_BSC;
            receiveLib = A.RECEIVE_ULN_BSC;
            executor = A.EXECUTOR_BSC;
            confirms = A.CONFIRMATIONS_BSC;
            optionalDvns = _envDvns();
        } else if (chainId == 80094) {
            remoteEid = A.EID_HYPEREVM;
            sendLib = A.SEND_ULN_BERA;
            receiveLib = A.RECEIVE_ULN_BERA;
            executor = A.EXECUTOR_BERA;
            confirms = A.CONFIRMATIONS_BERA;
            optionalDvns = _envDvns();
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
        console2.log("remoteEid", remoteEid);
        console2.log("hyperleaf veto dvn", hyperleafDvn);
    }

    function _envDvns() internal view returns (address[] memory d) {
        d = new address[](3);
        d[0] = vm.envAddress("DVN0");
        d[1] = vm.envAddress("DVN1");
        d[2] = vm.envAddress("DVN2");
    }
}
