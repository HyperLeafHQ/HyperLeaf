// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Canonical LayerZero V2 addresses used by Hyperleaf wrap.
/// @dev Google Cloud DVN is on Base but NOT on HyperEVM. Optional 2-of-3 is
///      LayerZero Labs + Horizen + Canary (present on Base, HyperEVM, BSC,
///      Bera, Arb, Avax). Nethermind left the LZ DVN role 2026-08-19 — do
///      not put it back. Addresses from metadata.layerzero-api.com/v1/metadata/dvns
///      (canonicalName, version 2, not lzRead).
library LayerZeroAddresses {
    uint32 internal constant EID_ETH = 30101;
    uint32 internal constant EID_BASE = 30184;
    uint32 internal constant EID_HYPEREVM = 30367;
    uint32 internal constant EID_BSC = 30102;
    uint32 internal constant EID_AVALANCHE = 30106;
    uint32 internal constant EID_ARB = 30110;
    uint32 internal constant EID_OP = 30111;
    uint32 internal constant EID_ORDERLY = 30213;
    uint32 internal constant EID_BERA = 30362;
    uint32 internal constant EID_ROBINHOOD = 30416;
    uint32 internal constant EID_SOLANA = 30168;
    uint32 internal constant EID_BERA_TESTNET = 40371;
    uint32 internal constant EID_BASE_SEPOLIA = 40245;
    uint32 internal constant EID_HYPEREVM_TESTNET = 40362;
    uint32 internal constant EID_BSC_TESTNET = 40102;
    uint32 internal constant EID_AVALANCHE_FUJI = 40106;
    uint32 internal constant EID_SEPOLIA = 40161;
    uint32 internal constant EID_ARB_SEPOLIA = 40231;

    address internal constant ENDPOINT_BASE = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal constant SEND_ULN_BASE = 0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2;
    address internal constant RECEIVE_ULN_BASE = 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf;
    address internal constant EXECUTOR_BASE = 0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4;

    address internal constant ENDPOINT_HYPEREVM = 0x3A73033C0b1407574C76BdBAc67f126f6b4a9AA9;
    address internal constant SEND_ULN_HYPEREVM = 0xfd76d9CB0Bac839725aB79127E7411fe71b1e3CA;
    address internal constant RECEIVE_ULN_HYPEREVM = 0x7cacBe439EaD55fa1c22790330b12835c6884a91;
    address internal constant EXECUTOR_HYPEREVM = 0x41Bdb4aa4A63a5b2Efc531858d3118392B1A1C3d;

    /// @dev Same canonical V2 endpoint as most EVMs including BSC.
    address internal constant ENDPOINT_BSC = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal constant SEND_ULN_BSC = 0x9F8C645f2D0b2159767Bd6E0839DE4BE49e823DE;
    address internal constant RECEIVE_ULN_BSC = 0xB217266c3A98C8B2709Ee26836C98cf12f6cCEC1;
    address internal constant EXECUTOR_BSC = 0x3ebD570ed38B1b3b4BC886999fcF507e9D584859;
    /// @dev Berachain is NOT the canonical 0x1a44… CREATE2. Confirmed bytecode on 80094.
    address internal constant ENDPOINT_BERA = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
    address internal constant SEND_ULN_BERA = 0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7;
    address internal constant RECEIVE_ULN_BERA = 0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043;
    address internal constant EXECUTOR_BERA = 0x4208D6E27538189bB48E603D6123A94b8Abe0A0b;

    address internal constant ENDPOINT_BASE_SEPOLIA = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address internal constant ENDPOINT_HYPEREVM_TESTNET = 0xf9e1815F151024bDE4B7C10BAC10e8Ba9F6b53E1;
    address internal constant ENDPOINT_BSC_TESTNET = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    address internal constant SEND_ULN_HYPEREVM_TESTNET = 0x43E505ba192aaC7BABdC1A796c87844171011684;
    address internal constant RECEIVE_ULN_HYPEREVM_TESTNET = 0x012f6eaE2A0Bf5916f48b5F37C62Bcfb7C1ffdA1;
    address internal constant EXECUTOR_HYPEREVM_TESTNET = 0x72e34F44Eb09058bdDaf1aeEebDEC062f1844b00;

    function endpoint(uint256 chainId) internal pure returns (address) {
        if (chainId == 8453) return ENDPOINT_BASE;
        if (chainId == 84532) return ENDPOINT_BASE_SEPOLIA;
        if (chainId == 56) return ENDPOINT_BSC;
        if (chainId == 97) return ENDPOINT_BSC_TESTNET;
        if (chainId == 43113) return ENDPOINT_BASE_SEPOLIA; // Fuji V2 endpoint, same CREATE2
        if (chainId == 11155111) return ENDPOINT_BASE_SEPOLIA; // Sepolia V2 endpoint
        if (chainId == 42161 || chainId == 10) return ENDPOINT_BSC; // canonical V2, same as Base
        if (chainId == 421614) return ENDPOINT_BASE_SEPOLIA; // Arb Sepolia V2, same CREATE2 as Base Sepolia
        if (chainId == 80094) return ENDPOINT_BERA;
        if (chainId == 4663) return ENDPOINT_BERA; // Robinhood mainnet: same CREATE2 as Bera (LZ docs)
        if (chainId == 80069) revert("lz: Bepolia EndpointV2 not deployed");
        if (chainId == 999) return ENDPOINT_HYPEREVM;
        if (chainId == 998) return ENDPOINT_HYPEREVM_TESTNET;
        revert("lz: no endpoint");
    }

    // Optional 2-of-3. Sorted ascending per ULN requirement.
    address internal constant DVN_CANARY_BASE = 0x554833698Ae0FB22ECC90B01222903fD62CA4B47;
    address internal constant DVN_LZ_LABS_BASE = 0x9e059a54699a285714207b43B055483E78FAac25;
    address internal constant DVN_HORIZEN_BASE = 0xa7b5189bcA84Cd304D8553977c7C614329750d99;

    address internal constant DVN_CANARY_HYPEREVM = 0x83342EC538dF0460e730a8F543Fe63063e2D44C4;
    address internal constant DVN_HORIZEN_HYPEREVM = 0xBB83Ecf372CbB6daa629ea9A9A53BEC6d601F229;
    address internal constant DVN_LZ_LABS_HYPEREVM = 0xc097ab8CD7b053326DFe9fB3E3a31a0CCe3B526f;

    address internal constant DVN_HORIZEN_BSC = 0x247624e2143504730aeC22912ed41F092498bEf2;
    address internal constant DVN_CANARY_BSC = 0xfA9bA83C102283958B997Adc8B44ED3A3CdB5dDa;
    address internal constant DVN_LZ_LABS_BSC = 0xfD6865c841c2d64565562fCc7e05e619A30615f0;

    address internal constant DVN_CANARY_BERA = 0x06e8042729CeF3aE6D6DB5350f48F9D736C3675d;
    address internal constant DVN_LZ_LABS_BERA = 0x282b3386571f7f794450d5789911a9804FA346b4;
    address internal constant DVN_HORIZEN_BERA = 0xeCbaA45c33ce6Fa284995e5F8314f5bC7F1C2008;

    address internal constant DVN_HORIZEN_ARB = 0x19670Df5E16bEa2ba9b9e68b48C054C5bAEa06B8;
    address internal constant DVN_LZ_LABS_ARB = 0x2f55C492897526677C5B68fb199ea31E2c126416;
    address internal constant DVN_CANARY_ARB = 0xf2E380c90e6c09721297526dbC74f870e114dfCb;

    address internal constant DVN_HORIZEN_AVAX = 0x07C05EaB7716AcB6f83ebF6268F8EECDA8892Ba1;
    address internal constant DVN_LZ_LABS_AVAX = 0x962F502A63F5FBeB44DC9ab932122648E8352959;
    address internal constant DVN_CANARY_AVAX = 0xcC49E6fca014c77E1Eb604351cc1E08C84511760;

    address internal constant DVN_HORIZEN_ETH = 0x380275805876Ff19055EA900CDb2B46a94ecF20D;
    address internal constant DVN_LZ_LABS_ETH = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
    address internal constant DVN_CANARY_ETH = 0xa4fE5A5B9A846458a70Cd0748228aED3bF65c2cd;

    uint32 internal constant CONFIG_TYPE_EXECUTOR = 1;
    uint32 internal constant CONFIG_TYPE_ULN = 2;

    uint128 internal constant LZ_RECEIVE_GAS = 200_000;

    /// @dev Source-side ULN confirmations. Pathway is asymmetric:
    ///      Send ULN on A (dst=B) uses A's depth; Receive ULN on B (src=A)
    ///      must use the SAME number (blocks on A). Never copy local depth
    ///      onto the receive side of the other chain.
    ///      LZ floor: ETH 15 (32 preferred), optimistic L2 15–30, Solana 32.
    ///      HyperEVM is a ~1s L1 (Circle uses 1); 5 is above that.
    uint64 internal constant CONFIRMATIONS_BASE = 15;
    uint64 internal constant CONFIRMATIONS_OP = 15;
    uint64 internal constant CONFIRMATIONS_ARB = 15;
    uint64 internal constant CONFIRMATIONS_HYPEREVM = 5;
    uint64 internal constant CONFIRMATIONS_BSC = 15;
    uint64 internal constant CONFIRMATIONS_BERA = 15;
    uint64 internal constant CONFIRMATIONS_AVAX = 12;
    uint64 internal constant CONFIRMATIONS_ETH = 15;
    uint64 internal constant CONFIRMATIONS_SOLANA = 32;

    function confirmationsForEid(uint32 eid) internal pure returns (uint64) {
        if (eid == EID_BASE || eid == EID_OP) return CONFIRMATIONS_BASE;
        if (eid == EID_ARB) return CONFIRMATIONS_ARB;
        if (eid == EID_HYPEREVM) return CONFIRMATIONS_HYPEREVM;
        if (eid == EID_BSC) return CONFIRMATIONS_BSC;
        if (eid == EID_BERA) return CONFIRMATIONS_BERA;
        if (eid == EID_AVALANCHE) return CONFIRMATIONS_AVAX;
        if (eid == EID_ETH) return CONFIRMATIONS_ETH;
        if (eid == EID_SOLANA) return CONFIRMATIONS_SOLANA;
        revert("lz: no confirmations");
    }

    function eidForChainId(uint256 chainId) internal pure returns (uint32) {
        if (chainId == 8453) return EID_BASE;
        if (chainId == 999) return EID_HYPEREVM;
        if (chainId == 56) return EID_BSC;
        if (chainId == 80094) return EID_BERA;
        if (chainId == 42161) return EID_ARB;
        if (chainId == 43114) return EID_AVALANCHE;
        if (chainId == 10) return EID_OP;
        if (chainId == 1) return EID_ETH;
        revert("lz: no eid");
    }

    uint32 internal constant LOCK_4Y = 4 * 365 days;
}
