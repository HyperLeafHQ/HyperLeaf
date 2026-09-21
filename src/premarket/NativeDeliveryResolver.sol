// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {INativeDeliveryResolver} from "./INativeDeliveryResolver.sol";

/// @notice Operator attestation that QTC (or another native coin) was delivered
///         on the source chain. Owner should be a Safe. Not a light client.
///         Attestations may be overwritten or revoked until the factory settles
///         or defaults — a one-shot `ok` would permanently lock escrow on a
///         mistyped dest/amount (audit P1-01).
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
    event Revoked(bytes32 indexed offerId);

    error Zero();
    error NotAttested();

    constructor(address owner_) Ownable(owner_) {
        if (owner_ == address(0)) revert Zero();
    }

    /// @dev Last write wins. Owner may correct dest/amount before settle.
    function attest(bytes32 offerId, bytes32 txHash, bytes32 destHash, uint256 qtcAtoms) external onlyOwner {
        if (txHash == bytes32(0) || destHash == bytes32(0) || qtcAtoms == 0) revert Zero();
        _att[offerId] = Att(txHash, destHash, qtcAtoms, uint64(block.timestamp), true);
        emit Attested(offerId, txHash, destHash, qtcAtoms);
    }

    /// @dev Clears `ok` so `finalize` can default after the 48h window.
    function revoke(bytes32 offerId) external onlyOwner {
        if (!_att[offerId].ok) revert NotAttested();
        delete _att[offerId];
        emit Revoked(offerId);
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
