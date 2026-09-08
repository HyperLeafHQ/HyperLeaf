// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hLBTC pins. Ethereum LBTC only. Never BTC.b / LBTCv / native BTC redeem.
library LeafLbtcPolicy {
    address internal constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address internal constant BTCB = 0xB0F70C0bD6FD87dbEb7C10dC692a2a6106817072;
    address internal constant LBTCV = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c;
    address internal constant ASSET_ROUTER = 0x9eCe5fB1aB62d9075c4ec814b321e24D8EA021ac;
    /// @dev 8-dec inner → 18-dec hLBTC.
    uint256 internal constant SHARE_SCALE = 1e10;
    /// @dev Bitwise/admin rate. 3% one-step jump is not a covered-call premium.
    uint16 internal constant MAX_RATE_JUMP_BPS = 300;
    uint8 internal constant INNER_DECIMALS = 8;
}
