// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LeafTaoRootAdapter} from "../../src/lz/LeafTaoRootAdapter.sol";
import {LeafTaoRootPolicy} from "../../src/lz/LeafTaoRootPolicy.sol";
import {ITaoRootBasketAdapter} from "../../src/interfaces/ITaoRootBasketAdapter.sol";
import {ITaoRootStateVerifier} from "../../src/interfaces/ITaoRootStateVerifier.sol";

contract MockTaoVerifier is ITaoRootStateVerifier {
    VerifiedState public state;

    function setState(VerifiedState calldata next) external {
        state = next;
    }

    function verify(bytes32, bytes calldata) external view returns (VerifiedState memory) {
        return state;
    }
}

contract LeafTaoRootAdapterTest is Test {
    MockTaoVerifier verifier;
    LeafTaoRootAdapter adapter;

    bytes32 coldkey = bytes32(uint256(1));
    bytes32 validator = bytes32(uint256(2));
    bytes32 positionId = keccak256("alice:validator");

    function setUp() public {
        verifier = new MockTaoVerifier();
        adapter = new LeafTaoRootAdapter(address(this), address(verifier));
    }

    function _state(uint64 remoteBlock, uint256 beta, uint256 value)
        internal
        view
        returns (ITaoRootStateVerifier.VerifiedState memory)
    {
        return ITaoRootStateVerifier.VerifiedState({
            coldkey: coldkey,
            validatorHotkey: validator,
            netuid: 0,
            rootStakeRao: 100 ether,
            betaRaw: beta,
            valueTaoRao: value,
            remoteBlock: remoteBlock,
            specVersion: 441,
            stateHash: keccak256(abi.encode(coldkey, validator, remoteBlock, beta, value))
        });
    }

    function testAttestFromProofStoresCanonicalUnits() public {
        verifier.setState(_state(100, 2e9, 125e9));
        adapter.attestFromProof(positionId, hex"01");

        ITaoRootBasketAdapter.Position memory p = adapter.position(positionId);
        assertEq(p.coldkey, coldkey);
        assertEq(p.validatorHotkey, validator);
        assertEq(p.netuid, 0);
        assertEq(p.rootStakeRao, 100 ether);
        assertEq(p.betaRaw, 2e9);
        assertEq(p.valueTaoRao, 125e9);
        assertTrue(adapter.isHealthy(positionId));
    }

    function testRejectsWrongNetuid() public {
        ITaoRootStateVerifier.VerifiedState memory s = _state(100, 1e9, 1e9);
        s.netuid = 1;
        verifier.setState(s);
        vm.expectRevert(abi.encodeWithSelector(LeafTaoRootPolicy.WrongNetuid.selector, uint16(1)));
        adapter.attestFromProof(positionId, hex"01");
    }

    function testRejectsSnapshotRegression() public {
        verifier.setState(_state(100, 1e9, 1e9));
        adapter.attestFromProof(positionId, hex"01");

        verifier.setState(_state(99, 2e9, 2e9));
        vm.expectRevert(LeafTaoRootAdapter.SnapshotRegression.selector);
        adapter.attestFromProof(positionId, hex"02");
    }

    function testStalesUsingLocalAttestationTimeNotRemoteBlockNumber() public {
        verifier.setState(_state(1, 1e9, 1e9));
        adapter.attestFromProof(positionId, hex"01");
        assertTrue(adapter.isHealthy(positionId));

        vm.warp(block.timestamp + adapter.MAX_SNAPSHOT_AGE() + 1);
        assertFalse(adapter.isHealthy(positionId));
    }

    function testVerifierIsTheOnlyAttestCaller() public {
        ITaoRootBasketAdapter.RootState memory s = ITaoRootBasketAdapter.RootState({
            coldkey: coldkey,
            validatorHotkey: validator,
            netuid: 0,
            rootStakeRao: 1 ether,
            betaRaw: 1e9,
            valueTaoRao: 1e9,
            remoteBlock: 1,
            specVersion: 441,
            stateHash: keccak256("state")
        });

        vm.expectRevert(LeafTaoRootAdapter.NotVerifier.selector);
        adapter.attest(positionId, s);
    }
}
