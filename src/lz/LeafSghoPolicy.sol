// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hsGHO pins. New ERC-4626 sGHO on Ethereum only. Never GHO, never
///         Aave App / Stable Vault, never aUSDC sleeve, never Merit/legacy sGHO.
library LeafSghoPolicy {
    address internal constant SGHO = 0xE1753F2e00940cC31213dd92013cF019DFE4ca1d;
    address internal constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    error NotSgho();

    function requireSgho(address inner) internal pure {
        if (inner != SGHO) revert NotSgho();
    }
}
