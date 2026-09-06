// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LeafOFT} from "./LeafOFT.sol";

/// @title LeafClosedOFT
/// @notice C1 HyperEVM ticker. Transferable, mint-only from LZ, no protocol redeem.
///         Name/symbol must encode the lock (e.g. BLUAI4Y / Hyperliquid BLUAI 4Year).
contract LeafClosedOFT is LeafOFT {
    /// @notice Advertised lock length. Not enforced on-chain; the source stake is.
    uint32 public immutable lockSeconds;

    error ExitViaMarketOnly();

    constructor(
        string memory name_,
        string memory symbol_,
        uint32 lockSeconds_,
        address endpoint_,
        address owner_,
        address guardian_
    ) LeafOFT(name_, symbol_, endpoint_, owner_, guardian_) {
        lockSeconds = lockSeconds_;
    }

    function send(uint32, bytes32, uint256, address) public payable override returns (bytes32) {
        revert ExitViaMarketOnly();
    }
}
