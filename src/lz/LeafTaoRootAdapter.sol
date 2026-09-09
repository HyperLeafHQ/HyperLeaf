// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ITaoRootBasketAdapter} from "../interfaces/ITaoRootBasketAdapter.sol";
import {ITaoRootStateVerifier} from "../interfaces/ITaoRootStateVerifier.sol";
import {LeafTaoRootPolicy} from "./LeafTaoRootPolicy.sol";

/// @title LeafTaoRootAdapter
/// @notice Stores authenticated snapshots of a Bittensor Root Basket position.
/// @dev This is an accounting/verification shell, not a bridge implementation and not a
///      claim executor. A production deployment must plug in a verifier that proves the
///      remote Bittensor state and must bind the proof to the exact coldkey/hotkey/position.
contract LeafTaoRootAdapter is Ownable, ITaoRootBasketAdapter {
    uint64 public constant MAX_SNAPSHOT_AGE = 256;

    ITaoRootStateVerifier public verifier;
    bool public paused;

    mapping(bytes32 => Position) private positions;

    error NotVerifier();
    error UnknownPosition();
    error InvalidVerifier();
    error SnapshotRegression();
    error StaleSnapshot(uint64 remoteBlock, uint64 currentBlock);
    error AdapterPaused();

    event VerifierSet(address indexed verifier);
    event SnapshotAttested(
        bytes32 indexed positionId,
        bytes32 indexed coldkey,
        bytes32 indexed validatorHotkey,
        uint64 remoteBlock,
        uint256 rootStakeRao,
        uint256 betaRaw,
        uint256 valueTaoRao
    );
    event Paused(bool paused);

    constructor(address initialOwner, address initialVerifier) Ownable(initialOwner) {
        if (initialVerifier == address(0)) revert InvalidVerifier();
        verifier = ITaoRootStateVerifier(initialVerifier);
    }

    modifier onlyVerifier() {
        if (msg.sender != address(verifier)) revert NotVerifier();
        _;
    }

    function setVerifier(address nextVerifier) external onlyOwner {
        if (nextVerifier == address(0)) revert InvalidVerifier();
        verifier = ITaoRootStateVerifier(nextVerifier);
        emit VerifierSet(nextVerifier);
    }

    function setPaused(bool value) external onlyOwner {
        paused = value;
        emit Paused(value);
    }

    /// @notice Verify and store a remote Root Basket snapshot.
    /// @dev The verifier owns all transport/authentication semantics. This contract only checks
    ///      the normalized output and monotonicity of the remote block for the same position.
    function attest(bytes32 positionId, RootState calldata state) external onlyVerifier {
        if (paused) revert AdapterPaused();

        LeafTaoRootPolicy.validateSnapshot(
            state.coldkey,
            state.validatorHotkey,
            state.netuid,
            state.betaRaw,
            state.valueTaoRao,
            state.specVersion,
            state.stateHash
        );

        Position storage current = positions[positionId];
        if (current.remoteBlock != 0 && state.remoteBlock < current.remoteBlock) {
            revert SnapshotRegression();
        }

        current.coldkey = state.coldkey;
        current.validatorHotkey = state.validatorHotkey;
        current.netuid = state.netuid;
        current.rootStakeRao = state.rootStakeRao;
        current.betaRaw = state.betaRaw;
        current.valueTaoRao = state.valueTaoRao;
        current.remoteBlock = state.remoteBlock;
        current.specVersion = state.specVersion;
        current.stateHash = state.stateHash;

        emit SnapshotAttested(
            positionId,
            state.coldkey,
            state.validatorHotkey,
            state.remoteBlock,
            state.rootStakeRao,
            state.betaRaw,
            state.valueTaoRao
        );
    }

    /// @notice Convenience hook for a bridge/verifier that owns the attestation call itself.
    function attestFromProof(bytes32 positionId, bytes calldata proof) external {
        if (paused) revert AdapterPaused();

        ITaoRootStateVerifier.VerifiedState memory state = verifier.verify(positionId, proof);
        RootState memory normalized = RootState({
            coldkey: state.coldkey,
            validatorHotkey: state.validatorHotkey,
            netuid: state.netuid,
            rootStakeRao: state.rootStakeRao,
            betaRaw: state.betaRaw,
            valueTaoRao: state.valueTaoRao,
            remoteBlock: state.remoteBlock,
            specVersion: state.specVersion,
            stateHash: state.stateHash
        });

        _attestUnchecked(positionId, normalized);
    }

    function position(bytes32 positionId) external view returns (Position memory) {
        Position memory p = positions[positionId];
        if (p.remoteBlock == 0) revert UnknownPosition();
        return p;
    }

    function positionValue(bytes32 positionId) external view returns (uint256 taoRao) {
        Position memory p = positions[positionId];
        if (p.remoteBlock == 0) revert UnknownPosition();
        return p.valueTaoRao;
    }

    function isHealthy(bytes32 positionId) external view returns (bool) {
        Position memory p = positions[positionId];
        if (p.remoteBlock == 0 || p.stateHash == bytes32(0)) return false;
        if (block.number > p.remoteBlock && block.number - p.remoteBlock > MAX_SNAPSHOT_AGE) return false;
        return p.netuid == LeafTaoRootPolicy.ROOT_NETUID;
    }

    function _attestUnchecked(bytes32 positionId, RootState memory state) internal {
        LeafTaoRootPolicy.validateSnapshot(
            state.coldkey,
            state.validatorHotkey,
            state.netuid,
            state.betaRaw,
            state.valueTaoRao,
            state.specVersion,
            state.stateHash
        );

        Position storage current = positions[positionId];
        if (current.remoteBlock != 0 && state.remoteBlock < current.remoteBlock) {
            revert SnapshotRegression();
        }

        current.coldkey = state.coldkey;
        current.validatorHotkey = state.validatorHotkey;
        current.netuid = state.netuid;
        current.rootStakeRao = state.rootStakeRao;
        current.betaRaw = state.betaRaw;
        current.valueTaoRao = state.valueTaoRao;
        current.remoteBlock = state.remoteBlock;
        current.specVersion = state.specVersion;
        current.stateHash = state.stateHash;

        emit SnapshotAttested(
            positionId,
            state.coldkey,
            state.validatorHotkey,
            state.remoteBlock,
            state.rootStakeRao,
            state.betaRaw,
            state.valueTaoRao
        );
    }
}
