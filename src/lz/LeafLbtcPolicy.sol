// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hLBTC pins. Ethereum LBTC only. Never BTC.b / LBTCv / BTCe / Base LBTC / native BTC redeem.
library LeafLbtcPolicy {
    address internal constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address internal constant BTCB = 0xB0F70C0bD6FD87dbEb7C10dC692a2a6106817072;
    address internal constant LBTCV = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c;
    address internal constant BTCE = 0x3a4baaBf4DC9910596821615e848f0e6545762F3;
    address internal constant BASE_LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
    address internal constant ASSET_ROUTER = 0x9eCe5fB1aB62d9075c4ec814b321e24D8EA021ac;
    /// @dev 8-dec inner → 18-dec hLBTC.
    uint256 internal constant SHARE_SCALE = 1e10;
    /// @dev Bitwise/admin rate. 3% one-step jump (up or down) is not a covered-call premium.
    uint16 internal constant MAX_RATE_JUMP_BPS = 300;
    uint8 internal constant INNER_DECIMALS = 8;

    error NotLbtc();

    function requireLbtc(address inner) internal pure {
        if (inner != LBTC) revert NotLbtc();
    }

    /// @dev Dest share units per inner atom. 1e10 for hlbtc; 1 otherwise.
    function shareScaleOf(string memory id) internal pure returns (uint256) {
        bytes32 k = keccak256(bytes(id));
        if (k == keccak256("hlbtc") || k == keccak256("hLBTC")) return SHARE_SCALE;
        if (k == keccak256("hhbarx") || k == keccak256("hHBARX")) return SHARE_SCALE;
        return 1;
    }
}
