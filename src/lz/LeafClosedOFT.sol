// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LeafOFT} from "./LeafOFT.sol";

/// @title LeafClosedOFT
/// @notice C1 HyperEVM ticker. Transferable, mint-only from LZ, no protocol redeem.
///         Name/symbol must encode the lock (e.g. BLUAI4Y / Hyperliquid BLUAI 4Year).
contract LeafClosedOFT is LeafOFT {
    /// @notice Advertised lock length. Not enforced on-chain; the source stake is.
    uint32 public immutable lockSeconds;
    /// @notice Owner may open protocol redeem after the source lock ends (BLUAI).
    bool public redeemEnabled;

    error ExitViaMarketOnly();

    event RedeemEnabled(bool on);

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

    function setRedeemEnabled(bool on) external onlyOwner {
        redeemEnabled = on;
        emit RedeemEnabled(on);
    }

    function send(uint32 dstEid, bytes32 to, uint256 amount, address refund)
        public
        payable
        override
        returns (bytes32)
    {
        if (!redeemEnabled) revert ExitViaMarketOnly();
        return super.send(dstEid, to, amount, refund);
    }
}
