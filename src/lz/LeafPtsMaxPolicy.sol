// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RiverPtsAddresses as R} from "./IRiverPts.sol";

/// @notice PTSMAX pins. BSC only. Convert epoch 7. Never V1 unstake.
library LeafPtsMaxPolicy {
    address internal constant PTS = R.PTS;
    address internal constant RIVER = R.RIVER;
    address internal constant CONVERT = R.CONVERT;
    address internal constant SRIVER_V2 = R.SRIVER_V2;
    address internal constant SRIVER_V1 = R.SRIVER_V1;
    address internal constant PTS_MERKLE = R.PTS_MERKLE;
    bytes4 internal constant CONVERT_SEL = R.CONVERT_SELECTOR; // 0x03063b98
    bytes4 internal constant UNSTAKE_SEL = R.UNSTAKE_SELECTOR; // 0x2e17de78
    bytes4 internal constant CLAIM_PTS_SEL = R.CLAIM_PTS_SELECTOR; // 0xae0b51df
    uint256 internal constant EPOCH_MAX = R.EPOCH_MAX; // 7
    uint256 internal constant P1 = 1;
    /// @dev sRIVER_V2 #22014 unlock 2028-10-01 14:00 UTC. Not a duration.
    uint64 internal constant UNLOCK_AT = 1_854_021_600;

    error WrongInner();
    error WrongChain();
    error WrongConvert();
    error WrongNft();
    error V1Forbidden();
    error UnstakeForbidden();

    function requireBsc(uint256 chainId) internal pure {
        if (chainId != 56) revert WrongChain();
    }

    function requireLive(address pts, address convert_, address sRiver) internal pure {
        if (pts != PTS) revert WrongInner();
        if (convert_ != CONVERT) revert WrongConvert();
        if (sRiver != SRIVER_V2) revert WrongNft();
        if (sRiver == SRIVER_V1) revert V1Forbidden();
    }

    function requireEpochMax(uint256 epoch) internal pure {
        if (epoch != EPOCH_MAX) revert WrongConvert();
    }
}
