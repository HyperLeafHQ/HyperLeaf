// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IConversionResolver} from "./IConversionResolver.sol";

/// @notice Owner is the oracle. One-shot. A voided market can never resolve.
contract MultisigResolver is IConversionResolver {
    address public owner;

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
    event OwnerTransferred(address indexed oldOwner, address indexed newOwner);

    error AlreadyResolved();
    error MarketAlreadyVoided();
    error NotOwner();
    error ZeroAddressOrRate();

    constructor(address owner_) {
        if (owner_ == address(0)) revert ZeroAddressOrRate();
        owner = owner_;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address n) external onlyOwner {
        if (n == address(0)) revert ZeroAddressOrRate();
        emit OwnerTransferred(owner, n);
        owner = n;
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
