// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HypeAddresses as H} from "./HypeAddresses.sol";
import {IBluaiStake} from "./IBluaiStake.sol";

/// @notice BLUAI4Y pins. BSC only. Stake years must be 4. Unstake is owner+expiry.
library LeafBluaiPolicy {
    address internal constant BLUAI = 0xed9Ae3DEF8d6F052971Bb8b6d1975FF267Cf9aaD;
    address internal constant STAKE = H.BLUAI_STAKE_BSC;
    uint256 internal constant YEARS = 4;
    bytes4 internal constant STAKE_SEL = IBluaiStake.stake.selector; // 0x7b0472f0
    bytes4 internal constant CLAIM_ALL = IBluaiStake.claimAll.selector; // 0xd1058e59
    bytes4 internal constant UNSTAKE = IBluaiStake.unstake.selector; // 0x2e17de78

    error WrongInner();
    error WrongChain();
    error WrongYears();

    function requireBscBluai(address inner, uint256 chainId) internal pure {
        if (chainId != 56) revert WrongChain();
        if (inner != BLUAI) revert WrongInner();
    }

    function requireFourYears(uint256 years_) internal pure {
        if (years_ != YEARS) revert WrongYears();
    }
}
