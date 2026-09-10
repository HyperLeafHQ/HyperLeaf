// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Compile-time wrap listings. Scripts take ASSET=<id>.
/// @dev Solana/Monad listings have no EVM inner. Do not mock them on Base.
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
        /// @dev Raw token units. 0 means OpenPeg must receive an explicit PEG_CAP
        ///      (hstkwausdc 6-dec, gated hsETHFI). Non-18d production assets must
        ///      not silently inherit a 1e18-looking default.
        uint256 defaultCap;
        bool productionEvm;
    }

    error UnknownAsset();

    function get(string memory id) internal pure returns (Listing memory a) {
        bytes32 k = keccak256(bytes(id));
        if (k == keccak256("hcanary")) {
            return Listing(
                Kind.Liquid,
                "hcanary",
                "Hyperleaf Canary",
                "hCANARY",
                "LEAFTEST",
                8453,
                30184,
                40245,
                0,
                0,
                address(0),
                5e16,
                true
            );
        }
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
        if (k == keccak256("havnt")) {
            return Listing(
                Kind.Liquid,
                "havnt",
                "Hyperleaf stkAVNT",
                "hAVNT",
                "stkAVNT",
                8453,
                30184,
                40245,
                0,
                0,
                0xd546040F08E6b3A4F1D21683b9bd9935d73bd9e9,
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
        if (k == keccak256("horder") || k == keccak256("hORDER")) {
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
        if (k == keccak256("hstkwausdc") || k == keccak256("hstkwaUSDC")) {
            return Listing(
                Kind.Liquid,
                "hstkwausdc",
                "Hyperleaf stkwaEthUSDC.v1",
                "hstkwaUSDC",
                "stkwaUSDC",
                1,
                30101,
                40161,
                0,
                0,
                0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6,
                0,
                true
            );
        }
        if (k == keccak256("hspol") || k == keccak256("hsPOL") || k == keccak256("hSPOL")) {
            return Listing(
                Kind.Liquid,
                "hspol",
                "Hyperleaf sPOL",
                "hsPOL",
                "sPOL",
                1,
                30101,
                40161,
                0,
                0,
                0x3B790d651e950497c7723D47B24E6f61534f7969,
                50 ether,
                true
            );
        }
        if (k == keccak256("hsethfi") || k == keccak256("hethfi") || k == keccak256("hsETHFI")) {
            return Listing(
                Kind.Liquid,
                "hsethfi",
                "Hyperleaf sETHFI",
                "hsETHFI",
                "sETHFI",
                1,
                30101,
                40161,
                0,
                0,
                0x86B5780b606940Eb59A062aA85a07959518c0161,
                0,
                false
            );
        }
        if (k == keccak256("hlbtc") || k == keccak256("hLBTC")) {
            return Listing(
                Kind.Liquid,
                "hlbtc",
                "Hyperleaf LBTC",
                "hLBTC",
                "LBTC",
                1,
                30101,
                40161,
                0,
                0,
                0x8236a87084f8B84306f72007F36F2618A5634494,
                5e6,
                true
            );
        }
        if (k == keccak256("hhbarx") || k == keccak256("hHBARX")) {
            return Listing(
                Kind.Liquid,
                "hhbarx",
                "Hyperleaf HBARX",
                "hHBARX",
                "HBARX",
                295,
                30316,
                40285,
                0,
                0,
                0x00000000000000000000000000000000000cbA44,
                1e11,
                false
            );
        }
        if (k == keccak256("hsgho") || k == keccak256("hsGHO")) {
            return Listing(
                Kind.Liquid,
                "hsgho",
                "Hyperleaf sGHO",
                "hsGHO",
                "sGHO",
                1,
                30101,
                40161,
                0,
                0,
                0xE1753F2e00940cC31213dd92013cF019DFE4ca1d,
                10_000 ether,
                false
            );
        }
        if (k == keccak256("hsusdf") || k == keccak256("hsUSDf")) {
            return Listing(
                Kind.Liquid,
                "hsusdf",
                "Hyperleaf sUSDf",
                "hsUSDf",
                "sUSDf",
                1,
                30101,
                40161,
                0,
                0,
                0xc8CF6D7991f15525488b2A83Df53468D682Ba4B0,
                10_000 ether,
                false
            );
        }
        if (k == keccak256("hsff") || k == keccak256("hsFF")) {
            return Listing(
                Kind.Liquid,
                "hsff",
                "Hyperleaf sFF",
                "hsFF",
                "sFF",
                1,
                30101,
                40161,
                0,
                0,
                0x1a0C3FfCbd101c6f2f6650DED9964c4A568C4D72,
                10_000 ether,
                false
            );
        }
        if (k == keccak256("hveaero") || k == keccak256("hveAERO")) {
            return Listing(
                Kind.Closed,
                "hveaero",
                "Hyperleaf veAERO",
                "hveAERO",
                "veAERO",
                8453,
                30184,
                40245,
                0,
                0,
                0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4,
                1_000 ether,
                true
            );
        }
        if (k == keccak256("hb3") || k == keccak256("hB3")) {
            return Listing(
                Kind.Closed,
                "hb3",
                "Hyperleaf staked B3",
                "hB3",
                "B3",
                8453,
                30184,
                40245,
                0,
                0,
                0xB3B32F9f8827D4634fE7d973Fa1034Ec9fdDB3B3,
                50 ether,
                false
            );
        }
        if (k == keccak256("hssui") || k == keccak256("hsSUI")) {
            return Listing(
                Kind.Liquid,
                "hssui",
                "Hyperleaf sSUI",
                "hsSUI",
                "sSUI",
                0,
                30378,
                40378,
                0,
                0,
                address(0),
                10 ether,
                false
            );
        }
        if (k == keccak256("hjitosol") || k == keccak256("hJitoSOL")) {
            return Listing(
                Kind.Liquid,
                "hjitosol",
                "Hyperleaf JitoSOL",
                "hJitoSOL",
                "JitoSOL",
                0,
                30168,
                40168,
                0,
                0,
                address(0),
                10 ether,
                false
            );
        }
        revert UnknownAsset();
    }

    /// @dev Orderly keys stake by EVM address on its own ledger. That is the
    ///      same *identity* idea as CREATE2 twins — not LZ wrap (custody + mint).
    ///      hORDER is **Arbitrum only**: one lockbox address is enough. Do not
    ///      deploy a Base/OP twin; two `openBridge` sources into one dest OFT
    ///      double-count `ledgerPrincipal`.
    function addressKeyed(string memory id) internal pure returns (bool) {

        return keccak256(bytes(id)) == keccak256("horder");
    }

    function allIds() internal pure returns (string[22] memory ids) {
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
            string("hswbera"),
            string("hstkwausdc"),
            string("hsethfi"),
            string("hspol"),
            string("havnt"),
            string("hlbtc"),
            string("hhbarx"),
            string("hsgho"),
            string("hsusdf"),
            string("hsff")
        ];
    }
}
