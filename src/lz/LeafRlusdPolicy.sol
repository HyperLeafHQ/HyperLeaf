// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILeafRlusdAsset {
    function asset() external view returns (address);
}

/// @notice hRLUSD pins. Sentora RLUSD Main V2 shares on Ethereum only.
///         Never RLUSD, never Morpho Blue, never other Sentora vaults.
library LeafRlusdPolicy {
    address internal constant SEN_RLUSD = 0x6dC58a0FdfC8D694e571DC59B9A52EEEa780E6bf;
    address internal constant RLUSD = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
    address internal constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    uint16 internal constant MAX_RATE_JUMP_BPS = 300;
    uint256 internal constant DEFAULT_SHARE_CAP = 10_000 ether;

    error NotSenRlusd();
    error BadUnderlying();

    function requireSenRlusd(address inner) internal pure {
        if (inner != SEN_RLUSD) revert NotSenRlusd();
    }

    /// @dev Configure-time: vault address + live `asset()`. Do not pin impl.
    function requireSenRlusdLive(address inner) internal view {
        requireSenRlusd(inner);
        if (ILeafRlusdAsset(inner).asset() != RLUSD) revert BadUnderlying();
    }
}
