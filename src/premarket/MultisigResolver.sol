// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IConversionResolver} from "./IConversionResolver.sol";

/// @notice Resolution key. Owner should be a Safe in production.
///         One-shot resolve / void. Official token may live on another chain.
contract MultisigResolver is IConversionResolver, Ownable2Step {
    struct Res {
        uint64 originChainId;
        address token;
        uint8 tokenDecimals;
        uint256 rateX18;
        uint64 resolvedAt;
        bool resolved;
    }

    mapping(bytes32 => Res) internal _res;
    mapping(bytes32 => bool) internal _voided;

    event Resolved(bytes32 indexed marketId, uint64 originChainId, address token, uint8 decimals, uint256 rateX18);
    event MarketVoided(bytes32 indexed marketId);

    error AlreadyResolved();
    error MarketAlreadyVoided();
    error ZeroAddressOrRate();

    constructor(address owner_) Ownable(owner_) {
        if (owner_ == address(0)) revert ZeroAddressOrRate();
    }

    /// @param originChainId EVM id of the official token (42161 Arb, 999 HyperEVM, …).
    /// @param token Official ERC-20 on that chain. Not a tx hash.
    /// @param tokenDecimals Decimals of that token (cannot be read cross-chain).
    /// @param rateX18 1e18 = 1 whole official token per 1 whole claim.
    function resolve(bytes32 marketId, uint64 originChainId, address token, uint8 tokenDecimals, uint256 rateX18)
        external
        onlyOwner
    {
        if (_res[marketId].resolved) revert AlreadyResolved();
        if (_voided[marketId]) revert MarketAlreadyVoided();
        if (originChainId == 0 || token == address(0) || rateX18 == 0) revert ZeroAddressOrRate();
        _res[marketId] = Res(originChainId, token, tokenDecimals, rateX18, uint64(block.timestamp), true);
        emit Resolved(marketId, originChainId, token, tokenDecimals, rateX18);
    }

    function voidMarket(bytes32 marketId) external onlyOwner {
        if (_res[marketId].resolved) revert AlreadyResolved();
        _voided[marketId] = true;
        emit MarketVoided(marketId);
    }

    function resolution(bytes32 marketId)
        external
        view
        returns (uint64, address, uint8, uint256, uint64, bool)
    {
        Res storage r = _res[marketId];
        return (r.originChainId, r.token, r.tokenDecimals, r.rateX18, r.resolvedAt, r.resolved);
    }

    function voided(bytes32 marketId) external view returns (bool) {
        return _voided[marketId];
    }
}
