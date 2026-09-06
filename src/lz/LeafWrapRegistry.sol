// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract LeafWrapRegistry is Ownable2Step {
    enum Kind {
        Liquid,
        Closed,
        Queued
    }

    struct Asset {
        address innerToken;
        uint32 sourceEid;
        address adapter;
        address oft;
        Kind kind;
        bool active;
        string symbol;
    }

    mapping(bytes32 id => Asset) public assets;
    bytes32[] public assetIds;

    event Registered(bytes32 indexed id, address innerToken, address adapter, address oft, Kind kind, string symbol);
    event ActiveSet(bytes32 indexed id, bool active);

    error ZeroAddress();
    error AlreadyRegistered();
    error Unknown();

    constructor(address owner_) Ownable(owner_) {}

    function register(
        bytes32 id,
        address innerToken,
        uint32 sourceEid,
        address adapter,
        address oft,
        Kind kind,
        string calldata symbol
    ) external onlyOwner {
        if (innerToken == address(0) || adapter == address(0) || oft == address(0)) revert ZeroAddress();
        if (assets[id].adapter != address(0)) revert AlreadyRegistered();
        assets[id] = Asset(innerToken, sourceEid, adapter, oft, kind, true, symbol);
        assetIds.push(id);
        emit Registered(id, innerToken, adapter, oft, kind, symbol);
    }

    function setActive(bytes32 id, bool active) external onlyOwner {
        if (assets[id].adapter == address(0)) revert Unknown();
        assets[id].active = active;
        emit ActiveSet(id, active);
    }

    function allIds() external view returns (bytes32[] memory) {
        return assetIds;
    }
}
