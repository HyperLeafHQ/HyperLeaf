// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITaoRootStateVerifier {
    struct VerifiedState {
        bytes32 coldkey;
        bytes32 validatorHotkey;
        uint16 netuid;
        uint256 rootStakeRao;
        uint256 betaRaw;
        uint256 valueTaoRao;
        uint64 remoteBlock;
        uint32 specVersion;
        bytes32 stateHash;
    }

    function verify(bytes32 positionId, bytes calldata proof)
        external
        view
        returns (VerifiedState memory state);
}
