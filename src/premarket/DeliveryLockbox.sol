// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IDeliverySink {
    function onDeliveryCredit(bytes32 seriesId, uint256 amount) external;
    function officialTokenOf(bytes32 seriesId) external view returns (address);
}

/// @notice Credits delivery of the resolver's officialToken on the settlement chain.
///         That ERC-20 is what holders receive on SETTLED. Cross-chain is only a
///         way to move that same token here — not a second representation.
contract DeliveryLockbox {
    using SafeERC20 for IERC20;

    address public owner;
    IDeliverySink public factory;
    mapping(bytes32 => uint256) public lockedOrigin;
    mapping(bytes32 => bool) public credited;

    error NotOwner();
    error BadToken();
    error NotFactory();

    event Credited(bytes32 indexed seriesId, uint256 amount);
    event OriginLocked(bytes32 indexed seriesId, uint256 amount);

    constructor(address owner_) {
        owner = owner_;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function setFactory(address f) external onlyOwner {
        factory = IDeliverySink(f);
    }

    /// @dev Origin-chain lock (book-keeping for tests / later LZ). Does not
    ///      extend the 48h window. Credit on HyperEVM is a separate call.
    function lockOrigin(bytes32 seriesId, uint256 amount) external {
        lockedOrigin[seriesId] += amount;
        emit OriginLocked(seriesId, amount);
    }

    /// @dev Settlement-chain credit. Token MUST be the series officialToken.
    function credit(bytes32 seriesId, uint256 amount) external {
        address tok = factory.officialTokenOf(seriesId);
        if (tok == address(0)) revert BadToken();
        IERC20(tok).safeTransferFrom(msg.sender, address(factory), amount);
        factory.onDeliveryCredit(seriesId, amount);
        credited[seriesId] = true;
        emit Credited(seriesId, amount);
    }
}
