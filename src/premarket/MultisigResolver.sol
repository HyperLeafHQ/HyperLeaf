// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IConversionResolver} from "./IConversionResolver.sol";

/// @notice Resolution key for the VAR canary. Owner should be a Safe in production.
///         One-shot resolve / void. A voided market can never resolve.
contract MultisigResolver is IConversionResolver, Ownable2Step {
    struct Res {
        address token;
        uint256 rateX18;
        uint64 resolvedAt;
        bool resolved;
    }

    mapping(bytes32 => Res) internal _res;
    mapping(bytes32 => bool) internal _voided;

    event Resolved(bytes32 indexed marketId, address token, uint256 rateX18);
    event MarketVoided(bytes32 indexed marketId);

    error AlreadyResolved();
    error MarketAlreadyVoided();
    error ZeroAddressOrRate();

    constructor(address owner_) Ownable(owner_) {
        if (owner_ == address(0)) revert ZeroAddressOrRate();
    }

    function resolve(bytes32 marketId, address token, uint256 rateX18) external onlyOwner {
        if (_res[marketId].resolved) revert AlreadyResolved();
        if (_voided[marketId]) revert MarketAlreadyVoided();
        if (token == address(0) || rateX18 == 0) revert ZeroAddressOrRate();
        _res[marketId] = Res(token, rateX18, uint64(block.timestamp), true);
        emit Resolved(marketId, token, rateX18);
    }

    function voidMarket(bytes32 marketId) external onlyOwner {
        if (_res[marketId].resolved) revert AlreadyResolved();
        _voided[marketId] = true;
        emit MarketVoided(marketId);
    }

    function resolution(bytes32 marketId)
        external
        view
        returns (address, uint256, uint64, bool)
    {
        Res storage r = _res[marketId];
        return (r.token, r.rateX18, r.resolvedAt, r.resolved);
    }

    function voided(bytes32 marketId) external view returns (bool) {
        return _voided[marketId];
    }
}
