// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IPremarketDeliveryHub} from "./IPremarketDeliveryHub.sol";
import {PremarketOriginLock} from "./PremarketOriginLock.sol";

interface IFactoryCredit {
    function onDeliveryCredit(bytes32 seriesId, uint256 amount) external;
}

/// @notice Tests / same-EVM canary. Production Arb→HyperEVM uses an LZ hub.
contract PremarketSameChainHub is IPremarketDeliveryHub, Ownable2Step {
    PremarketOriginLock public origin;
    IFactoryCredit public factory;

    error Zero();
    error AlreadySet();
    error NotOrigin();
    error NotFactory();
    error UnexpectedValue();

    constructor(address owner_) Ownable(owner_) {
        if (owner_ == address(0)) revert Zero();
    }

    function setEnds(address origin_, address factory_) external onlyOwner {
        if (address(origin) != address(0) || address(factory) != address(0)) revert AlreadySet();
        if (origin_ == address(0) || factory_ == address(0)) revert Zero();
        origin = PremarketOriginLock(origin_);
        factory = IFactoryCredit(factory_);
    }

    function notifyCredit(bytes32 seriesId, uint256 amount, address refundTo) external payable {
        if (msg.value != 0) revert UnexpectedValue();
        if (refundTo == address(0)) revert Zero();
        if (msg.sender != address(origin)) revert NotOrigin();
        factory.onDeliveryCredit(seriesId, amount);
    }

    function notifyRelease(bytes32 seriesId, address to, uint256 amount) external payable {
        if (msg.value != 0) revert UnexpectedValue();
        if (msg.sender != address(factory)) revert NotFactory();
        origin.release(seriesId, to, amount);
    }
}
