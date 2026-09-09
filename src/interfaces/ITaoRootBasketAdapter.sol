// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ITaoRootBasketAdapter
/// @notice Verification boundary for a HyperLeaf representation of a Bittensor Root Basket position.
/// @dev The Bittensor state is remote. Do not treat caller-supplied values as proof. A concrete
///      transport/verifier must authenticate the remote state before invoking `attest`.
interface ITaoRootBasketAdapter {
    struct Position {
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

    struct RootState {
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

    function position(bytes32 positionId) external view returns (Position memory);

    function positionValue(bytes32 positionId) external view returns (uint256 taoRao);

    function isHealthy(bytes32 positionId) external view returns (bool);

    function attest(bytes32 positionId, RootState calldata state) external;
}
