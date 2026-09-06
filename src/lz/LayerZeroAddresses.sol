// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Canonical LayerZero V2 addresses used by Hyperleaf wrap.
/// @dev Google Cloud DVN is on Base but NOT on HyperEVM. Optional 2-of-3 is
///      LayerZero Labs + Nethermind + Horizen (present on both).
///      BSC DVNs are not hardcoded - pull from metadata before SetSecurityStack.
library LayerZeroAddresses {
    uint32 internal constant EID_BASE = 30184;
    uint32 internal constant EID_HYPEREVM = 30367;
    uint32 internal constant EID_BSC = 30102;
    uint32 internal constant EID_AVALANCHE = 30106;
    uint32 internal constant EID_BASE_SEPOLIA = 40245;
    uint32 internal constant EID_HYPEREVM_TESTNET = 40362;
    uint32 internal constant EID_BSC_TESTNET = 40102;
    uint32 internal constant EID_AVALANCHE_FUJI = 40106;

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
        if (chainId == 999) return ENDPOINT_HYPEREVM;
        if (chainId == 998) return ENDPOINT_HYPEREVM_TESTNET;
        revert("lz: no endpoint");
    }

    address internal constant DVN_LZ_LABS_BASE = 0x9e059a54699a285714207b43B055483E78FAac25;
    address internal constant DVN_HORIZEN_BASE = 0xa7b5189bcA84Cd304D8553977c7C614329750d99;
    address internal constant DVN_NETHERMIND_BASE = 0xcd37CA043f8479064e10635020c65FfC005d36f6;

    address internal constant DVN_NETHERMIND_HYPEREVM = 0x8E49eF1DfAe17e547CA0E7526FfDA81FbaCA810A;
    address internal constant DVN_HORIZEN_HYPEREVM = 0xBB83Ecf372CbB6daa629ea9A9A53BEC6d601F229;
    address internal constant DVN_LZ_LABS_HYPEREVM = 0xc097ab8CD7b053326DFe9fB3E3a31a0CCe3B526f;

    uint32 internal constant CONFIG_TYPE_EXECUTOR = 1;
    uint32 internal constant CONFIG_TYPE_ULN = 2;

    uint128 internal constant LZ_RECEIVE_GAS = 200_000;
    uint64 internal constant CONFIRMATIONS_BASE = 12;
    uint64 internal constant CONFIRMATIONS_HYPEREVM = 5;
    uint64 internal constant CONFIRMATIONS_BSC = 15;

    uint32 internal constant LOCK_4Y = 4 * 365 days;
}
