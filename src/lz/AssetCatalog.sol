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
        if (k == keccak256("hcbeth")) {
            return Listing(
                Kind.Liquid,
                "hcbeth",
                "Hyperleaf cbETH",
                "hcbETH",
                "cbETH",
                8453,
                30184,
                40245,
                0,
                0,
                0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22,
                10 ether,
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
                1,
                30101,
                40161,
                0,
                0,
                0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
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
        if (k == keccak256("horder")) {
            return Listing(
                Kind.Closed,
                "horder",
                "Hyperleaf staked ORDER",
                "hORDER",
                "ORDER",
                42161,
                30110,
                40231,
                0,
                0,
                0x4E200fE2f3eFb977d5fd9c430A41531FB04d97B8,
                1_000 ether,
                true
            );
        }
        if (k == keccak256("hgsoon")) {
            return Listing(
                Kind.Liquid,
                "hgsoon",
                "Hyperleaf gSOON",
                "hgSOON",
                "gSOON",
                56,
                30102,
                40102,
                0,
                0,
                0xcC48B55F6c16d4248EC6D78c11Ba19c1183Fe0F7,
                1_000 ether,
                true
            );
        }
        if (k == keccak256("hswbera")) {
            return Listing(
                Kind.Liquid,
                "hswbera",
                "Hyperleaf sWBERA",
                "hsWBERA",
                "sWBERA",
                80094,
                30362,
                40371,
                0,
                0,
                0x118D2cEeE9785eaf70C15Cd74CD84c9f8c3EeC9a,
                1_000 ether,
                true
            );
        }
        revert UnknownAsset();
    }

    /// @dev Source ledger keys by EVM address. CREATE2 the lockbox on every
    ///      OFT chain you will receive on (Arb/Base). Do not deploy two addresses.
    function addressKeyed(string memory id) internal pure returns (bool) {
        return keccak256(bytes(id)) == keccak256("horder");
    }

    function allIds() internal pure returns (string[13] memory ids) {
        ids = [
            string("hkaito"),
            string("hxsquid"),
            string("hcbeth"),
            string("hsavax"),
            string("hvirtualmax"),
            string("bluai4y"),
            string("bonk12m"),
            string("hmet"),
            string("hshmon"),
            string("hwsteth"),
            string("horder"),
            string("hgsoon"),
            string("hswbera")
        ];
    }
}
