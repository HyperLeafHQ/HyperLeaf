// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hLBTCv pins. Wrap Lombard BTC Vault shares only.
///         Rate is Veda accountant getRateInQuote(LBTC), never getRate() (WBTC)
///         and never AssetRouter.getRate(LBTC).
///         Never wrap LBTC / BTC.b / WBTC / cbBTC / BTCe / Base LBTC.
///         Never teller deposit/withdraw (3d vault exit).
library LeafLbtcvPolicy {
    address internal constant LBTCV = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c;
    address internal constant ACCOUNTANT = 0x28634D0c5edC67CF2450E74deA49B90a4FF93dCE;
    address internal constant HOOK = 0x2eA43384F1A98765257bc6Cb26c7131dEbdEB9B3;
    address internal constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address internal constant BTCB = 0xB0F70C0bD6FD87dbEb7C10dC692a2a6106817072;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant BTCE = 0x3a4baaBf4DC9910596821615e848f0e6545762F3;
    address internal constant BASE_LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
    uint256 internal constant SHARE_SCALE = 1e10;
    uint16 internal constant MAX_RATE_JUMP_BPS = 300;
    uint8 internal constant INNER_DECIMALS = 8;

    error NotLbtcv();
    error BadLbtcvAccountant();
    error BadLbtcvQuote();

    function requireLbtcv(address inner) internal pure {
        if (inner != LBTCV) revert NotLbtcv();
    }

    function requireAccountant(address accountant) internal pure {
        if (accountant != ACCOUNTANT) revert BadLbtcvAccountant();
    }

    function requireQuote(address quote) internal pure {
        if (quote != LBTC) revert BadLbtcvQuote();
    }

    function shareScaleOf(string memory id) internal pure returns (uint256) {
        bytes32 k = keccak256(bytes(id));
        if (k == keccak256("hlbtcv") || k == keccak256("hLBTCv")) return SHARE_SCALE;
        return 1;
    }
}
