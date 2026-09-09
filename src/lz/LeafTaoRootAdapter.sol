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
    uint64 public constant MAX_SNAPSHOT_AGE = 1 days;

    ITaoRootStateVerifier public verifier;
    bool public paused;

    mapping(bytes32 => Position) private positions;
    mapping(bytes32 => uint256) public lastAttestedAt;

    error NotVerifier();
    error UnknownPosition();
    error InvalidVerifier();
    error SnapshotRegression();
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

    /// @notice Store a state snapshot returned by the configured verifier.
    /// @dev Only the verifier may call this path. A bridge/verifier integration should bind the
    ///      proof to positionId and authenticate the exact Bittensor source before reaching here.
    function attest(bytes32 positionId, RootState calldata state) external onlyVerifier {
        if (paused) revert AdapterPaused();
        _store(positionId, state);
    }

    /// @notice Verify a remote proof and store its normalized Bittensor state.
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

        _store(positionId, normalized);
    }

    function position(bytes32 positionId) external view returns (Position memory) {
        Position memory p = positions[positionId];
        if (lastAttestedAt[positionId] == 0) revert UnknownPosition();
        return p;
    }

    function positionValue(bytes32 positionId) external view returns (uint256 taoRao) {
        if (lastAttestedAt[positionId] == 0) revert UnknownPosition();
        return positions[positionId].valueTaoRao;
    }

    function isHealthy(bytes32 positionId) external view returns (bool) {
        Position memory p = positions[positionId];
        uint256 attestedAt = lastAttestedAt[positionId];
        if (attestedAt == 0 || p.stateHash == bytes32(0)) return false;
        if (block.timestamp - attestedAt > MAX_SNAPSHOT_AGE) return false;
        return p.netuid == LeafTaoRootPolicy.ROOT_NETUID && p.valueTaoRao != 0;
    }

    function _store(bytes32 positionId, RootState memory state) internal {
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
        lastAttestedAt[positionId] = block.timestamp;

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
