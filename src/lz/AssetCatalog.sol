// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Compile-time wrap listings. Scripts take ASSET=<id>.
/// @dev Production Solana/Monad/Sui listings still deploy a mock inner on
///      Base Sepolia so L/C1/C2 contracts can be exercised on testnet.
library AssetCatalog {
    enum Kind {
        Liquid,
        Closed,
        Queued
    }

    struct Listing {
        Kind kind;
        string id;
        string name;
        string symbol;
        string innerSymbol;
        uint256 sourceChainIdMain;
        uint32 sourceEidMain;
        uint32 sourceEidTest;
        uint32 lockSeconds;
        uint64 redeemDelay;
        address innerMainnet;
        uint256 defaultCap;
        bool productionEvm;
    }

    error UnknownAsset();

    function get(string memory id) internal pure returns (Listing memory a) {
        bytes32 k = keccak256(bytes(id));
        if (k == keccak256("hkaito")) {
            return Listing(
                Kind.Liquid,
                "hkaito",
                "Hyperleaf sKAITO",
                "hKAITO",
                "sKAITO",
                8453,
                30184,
                40245,
                0,
                0,
                0x548D3B444da39686d1a6F1544781d154e7cD1EF7,
                1_000 ether,
                true
            );
        }
        if (k == keccak256("hxsquid")) {
            return Listing(
                Kind.Liquid,
                "hxsquid",
                "Hyperleaf xSQUID",
                "hxSQUID",
                "xSQUID",
                8453,
                30184,
                40245,
                0,
                0,
                0x13af2Db622d167745518aBfD59a8C4FFEe54937a,
                1_000 ether,
                true
            );
        }
        if (k == keccak256("hwsteth")) {
            return Listing(
                Kind.Liquid,
                "hwsteth",
                "Hyperleaf wstETH",
                "hwstETH",
                "wstETH",
                8453,
                30184,
                40245,
                0,
                0,
                0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452,
                10 ether,
                true
            );
        }
        if (k == keccak256("hsavax")) {
            return Listing(
                Kind.Liquid,
                "hsavax",
                "Hyperleaf sAVAX",
                "hsAVAX",
                "sAVAX",
                43114,
                30106,
                40106,
                0,
                0,
                0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE,
                100 ether,
                true
            );
        }
        if (k == keccak256("hvirtualmax") || k == keccak256("virtual4y")) {
            return Listing(
                Kind.Closed,
                "hvirtualmax",
                "Hyperleaf VIRTUAL MAX",
                "hVIRTUALMAX",
                "VIRTUAL",
                8453,
                30184,
                40245,
                uint32(104 weeks),
                0,
                0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b,
                1_000 ether,
                true
            );
        }
        if (k == keccak256("bluai4y")) {
            return Listing(
                Kind.Closed,
                "bluai4y",
                "Hyperliquid BLUAI 4Year",
                "BLUAI4Y",
                "BLUAI",
                56,
                30102,
                40102,
                uint32(4 * 365 days),
                0,
                0xed9Ae3DEF8d6F052971Bb8b6d1975FF267Cf9aaD,
                1_000 ether,
                true
            );
        }
        if (k == keccak256("bonk12m")) {
            return Listing(
                Kind.Closed,
                "bonk12m",
                "Hyperliquid BONK 12Month",
                "BONK12M",
                "BONK",
                0,
                0,
                40245,
                uint32(365 days),
                0,
                address(0),
                1_000 ether,
                false
            );
        }
        if (k == keccak256("hmet")) {
            return Listing(
                Kind.Queued,
                "hmet",
                "Hyperleaf MET",
                "hMET",
                "MET",
                0,
                0,
                40245,
                0,
                uint64(21 days),
                address(0),
                1_000 ether,
                false
            );
        }
        if (k == keccak256("hshmon")) {
            return Listing(
                Kind.Liquid,
                "hshmon",
                "Hyperleaf shMON",
                "hshMON",
                "shMON",
                0,
                0,
                40245,
                0,
                0,
                address(0),
                1_000 ether,
                false
            );
        }
        revert UnknownAsset();
    }

    function allIds() internal pure returns (string[9] memory ids) {
        ids = [
            string("hkaito"),
            string("hxsquid"),
            string("hwsteth"),
            string("hsavax"),
            string("hvirtualmax"),
            string("bluai4y"),
            string("bonk12m"),
            string("hmet"),
            string("hshmon")
        ];
    }
}
