// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SetConfigParam} from "./interfaces/ILayerZeroEndpointV2.sol";
import {LayerZeroAddresses as A} from "./LayerZeroAddresses.sol";

/// @notice Encodes LayerZero ULN + Executor configs.
///         Default: optional 2-of-3 (LZ Labs, Horizen, Canary). Arrays MUST
///         be strictly ascending. Nethermind is not in the stack.
///         If `hyperleafDvn != 0`, it is a REQUIRED DVN (veto).
library LeafSecurity {
    struct UlnConfig {
        uint64 confirmations;
        uint8 requiredDVNCount;
        uint8 optionalDVNCount;
        uint8 optionalDVNThreshold;
        address[] requiredDVNs;
        address[] optionalDVNs;
    }

    struct ExecutorConfig {
        uint32 maxMessageSize;
        address executor;
    }

    function baseOptionalDvns() internal pure returns (address[] memory d) {
        d = new address[](3);
        d[0] = A.DVN_CANARY_BASE;
        d[1] = A.DVN_LZ_LABS_BASE;
        d[2] = A.DVN_HORIZEN_BASE;
    }

    function hyperevmOptionalDvns() internal pure returns (address[] memory d) {
        d = new address[](3);
        d[0] = A.DVN_CANARY_HYPEREVM;
        d[1] = A.DVN_HORIZEN_HYPEREVM;
        d[2] = A.DVN_LZ_LABS_HYPEREVM;
    }

    function bscOptionalDvns() internal pure returns (address[] memory d) {
        d = new address[](3);
        d[0] = A.DVN_HORIZEN_BSC;
        d[1] = A.DVN_CANARY_BSC;
        d[2] = A.DVN_LZ_LABS_BSC;
    }

    function beraOptionalDvns() internal pure returns (address[] memory d) {
        d = new address[](3);
        d[0] = A.DVN_CANARY_BERA;
        d[1] = A.DVN_LZ_LABS_BERA;
        d[2] = A.DVN_HORIZEN_BERA;
    }

    function arbOptionalDvns() internal pure returns (address[] memory d) {
        d = new address[](3);
        d[0] = A.DVN_HORIZEN_ARB;
        d[1] = A.DVN_LZ_LABS_ARB;
        d[2] = A.DVN_CANARY_ARB;
    }

    function avaxOptionalDvns() internal pure returns (address[] memory d) {
        d = new address[](3);
        d[0] = A.DVN_HORIZEN_AVAX;
        d[1] = A.DVN_LZ_LABS_AVAX;
        d[2] = A.DVN_CANARY_AVAX;
    }

    function ethOptionalDvns() internal pure returns (address[] memory d) {
        d = new address[](3);
        d[0] = A.DVN_HORIZEN_ETH;
        d[1] = A.DVN_LZ_LABS_ETH;
        d[2] = A.DVN_CANARY_ETH;
    }

    function ulnConfig(uint64 confirmations, address hyperleafDvn, address[] memory optionalDvns)
        internal
        pure
        returns (bytes memory)
    {
        address[] memory required;
        if (hyperleafDvn != address(0)) {
            required = new address[](1);
            required[0] = hyperleafDvn;
        } else {
            required = new address[](0);
        }
        UlnConfig memory cfg = UlnConfig({
            confirmations: confirmations,
            requiredDVNCount: uint8(required.length),
            optionalDVNCount: uint8(optionalDvns.length),
            optionalDVNThreshold: 2,
            requiredDVNs: required,
            optionalDVNs: optionalDvns
        });
        return abi.encode(cfg);
    }

    function executorConfig(address executor) internal pure returns (bytes memory) {
        return abi.encode(ExecutorConfig({maxMessageSize: 10_000, executor: executor}));
    }

    function paramsForPathway(
        uint32 remoteEid,
        uint64 confirmations,
        address hyperleafDvn,
        address[] memory optionalDvns,
        address executor
    ) internal pure returns (SetConfigParam[] memory params) {
        params = new SetConfigParam[](2);
        params[0] = SetConfigParam(remoteEid, A.CONFIG_TYPE_ULN, ulnConfig(confirmations, hyperleafDvn, optionalDvns));
        params[1] = SetConfigParam(remoteEid, A.CONFIG_TYPE_EXECUTOR, executorConfig(executor));
    }

    /// @dev Receive ULN has no executor. `confirmations` is the REMOTE chain's
    ///      depth (blocks on the source of inbound messages).
    function receiveParamsForPathway(
        uint32 remoteEid,
        uint64 confirmations,
        address hyperleafDvn,
        address[] memory optionalDvns
    ) internal pure returns (SetConfigParam[] memory params) {
        params = new SetConfigParam[](1);
        params[0] = SetConfigParam(remoteEid, A.CONFIG_TYPE_ULN, ulnConfig(confirmations, hyperleafDvn, optionalDvns));
    }
}
