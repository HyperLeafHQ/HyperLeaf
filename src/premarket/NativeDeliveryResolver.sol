// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {INativeDeliveryResolver} from "./INativeDeliveryResolver.sol";

/// @notice Operator attestation that QTC (or another native coin) was delivered
///         on the source chain. Owner should be a Safe. One-shot. Not a light client.
contract NativeDeliveryResolver is INativeDeliveryResolver, Ownable2Step {
    struct Att {
        bytes32 txHash;
        bytes32 destHash;
        uint256 qtcAtoms;
        uint64 attestedAt;
        bool ok;
    }

    mapping(bytes32 => Att) internal _att;

    event Attested(bytes32 indexed offerId, bytes32 txHash, bytes32 destHash, uint256 qtcAtoms);

    error AlreadyAttested();
    error Zero();

    constructor(address owner_) Ownable(owner_) {
        if (owner_ == address(0)) revert Zero();
    }

    function attest(bytes32 offerId, bytes32 txHash, bytes32 destHash, uint256 qtcAtoms) external onlyOwner {
        if (_att[offerId].ok) revert AlreadyAttested();
        if (txHash == bytes32(0) || destHash == bytes32(0) || qtcAtoms == 0) revert Zero();
        _att[offerId] = Att(txHash, destHash, qtcAtoms, uint64(block.timestamp), true);
        emit Attested(offerId, txHash, destHash, qtcAtoms);
    }

    function attestation(bytes32 offerId)
        external
        view
        returns (bytes32, bytes32, uint256, uint64, bool)
    {
        Att storage a = _att[offerId];
        return (a.txHash, a.destHash, a.qtcAtoms, a.attestedAt, a.ok);
    }
}
