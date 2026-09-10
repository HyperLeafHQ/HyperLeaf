// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hsPOL pins. Verified 2026-09-10 against official sources, not the eval note.
///
/// Docs: https://docs.polygon.technology/pos/concepts/tokens/spol
///   "Contract address (Ethereum mainnet): 0x3B790d651e950497c7723D47B24E6f61534f7969"
///   "Do not interact with contracts at any other address."
/// Source: https://github.com/0xPolygon/sPOL-contracts README Deployments
/// On-chain: controller.sPOLToken() / polToken() / convertSPOLtoPOL(1e18)
/// Rate: (totaldPOLBalance - feedPOLBalance) * 1e18 / totalsPOLBalance
///   live = convertSPOLtoPOL(1e18) = 1012347237242067203 (exact match).
/// convertSPOLtoPOL is **view**. Mutating exits are buySPOL / sellSPOL / withdrawPOL.
/// sellSPOL queues the PoS unbond (~80 checkpoints, ~2–3 days). Lockbox must never sell.
/// sPOL and controller are upgradeable proxies (AccessManager).
/// L2 sPOLChild uses a cached rate + 0.3% safety fee — not this listing.
library LeafSpolPolicy {
    address internal constant SPOL = 0x3B790d651e950497c7723D47B24E6f61534f7969;
    address internal constant CONTROLLER = 0xEaadA411F2600570796c341552b9869DA708a28B;
    address internal constant POL = 0x455e53CBB86018Ac2B8092FdCd39d8444aFFC3F6;
    address internal constant MESSENGER = 0x0356e303B375D5a11D9Eb7d57DBF544FeE6972C9;
    address internal constant ACCESS_MANAGER = 0x2c91c02793a50f6D55168a88183da687F572d350;
    /// @dev Polygon PoS sPOLChild. Official L2 token, cached rate. Never wrap.
    address internal constant CHILD = 0xd1CD49A08AeF3Af93457aEc17C786C2b7F48eCd7;

    bytes4 internal constant CONVERT_SPOL_TO_POL = 0xff8aaf7a;
    bytes4 internal constant CONVERT_POL_TO_SPOL = 0xc356a582;
    bytes4 internal constant SELL_SPOL = 0x5d43011f;
    bytes4 internal constant BUY_SPOL = 0xbb7914a3;
    bytes4 internal constant WITHDRAW_POL = 0x61ad860b;

    uint16 internal constant MAX_RATE_JUMP_BPS = 300;

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
