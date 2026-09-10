// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hsSUI pins. SpringSui **sSUI** only. Never raw SUI, never haSUI /
///         afSUI / vSUI / stSUI. Source is a Sui Move lockbox, not LeafOFTAdapter.
library LeafSsuiPolicy {
    /// @dev Suiscan / springsui.com coin type. Sui types are case-sensitive.
    string internal constant COIN_TYPE =
        "0x83556891f4a0f233ce7b05cfe7f957d4020492a34f5405b2cb9377d060bef4bf::spring_sui::SPRING_SUI";
    string internal constant RAW_SUI = "0x2::sui::SUI";

    uint32 internal constant EID = 30378;
    uint32 internal constant EID_TESTNET = 40378;
    uint8 internal constant INNER_DECIMALS = 9;
    /// @dev Dest LeafOFT is 18-dec. shares = atoms * 1e9.
    uint256 internal constant SHARE_SCALE = 1e9;

    error NotSsui();

    function coinTypeHash() internal pure returns (bytes32) {
        return keccak256(bytes(COIN_TYPE));
    }

    function requireSsui(string memory coinType) internal pure {
        if (keccak256(bytes(coinType)) != coinTypeHash()) revert NotSsui();
    }
}
