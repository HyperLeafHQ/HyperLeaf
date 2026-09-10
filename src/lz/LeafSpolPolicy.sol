// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hsPOL pins. Ethereum only. Wrap sPOL, never POL, never Polygon child.
///         Rate is controller.convertSPOLtoPOL(1e18) — sPOL is not ERC-4626.
library LeafSpolPolicy {
    address internal constant SPOL = 0x3B790d651e950497c7723D47B24E6f61534f7969;
    address internal constant CONTROLLER = 0xEaadA411F2600570796c341552b9869DA708a28B;
    address internal constant POL = 0x455e53CBB86018Ac2B8092FdCd39d8444aFFC3F6;
    /// @dev Polygon PoS sPOLChild. Same symbol, not this listing.
    address internal constant CHILD = 0xd1CD49A08AeF3Af93457aEc17C786C2b7F48eCd7;

    bytes4 internal constant CONVERT_SPOL_TO_POL = 0xff8aaf7a; // convertSPOLtoPOL(uint256)
    bytes4 internal constant CONVERT_POL_TO_SPOL = 0xc356a582; // convertPOLtoSPOL(uint256)

    uint16 internal constant MAX_RATE_JUMP_BPS = 300; // 3%, same class as LBTC

    error WrongInner();
    error WrongController();
    error WrongChain();

    function requireEth(uint256 chainId) internal pure {
        if (chainId != 1) revert WrongChain();
    }

    function requireSpol(address token) internal pure {
        if (token != SPOL) revert WrongInner();
        if (token == CHILD || token == POL) revert WrongInner();
    }

    function requireController(address c) internal pure {
        if (c != CONTROLLER) revert WrongController();
    }
}
