// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hJitoSOL constants + what the Solana program is allowed to CPI.
///         Holding JitoSOL in the PDA earns the stake-pool rate (staking + TOV
///         already in SOL-per-JitoSOL). It does **not** earn NCN rewards
///         (Switchboard SWTCH, TipRouter restake share). Those require depositing
///         JitoSOL into a Jito Vault (VRT) — slashing surface. We never do that.
library LeafJitoPolicy {
    bytes32 internal constant LISTING_TAG =
        0xb107d7c3ae6a8d34482b78c6bc32c75449c22961c64baba36758d5ab9789a40e; // keccak256("hjitosol")

    /// @dev J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn
    bytes32 internal constant JITO_MINT =
        0xfcd141e9832caf10ad917495ca0f271b5b293cd47027ea737007ed40eb39a0bd;
    /// @dev Jito4APyf642JPZPx3hGc6WWJ8zPKtRbRs4P815Awbb — read-only rate account
    bytes32 internal constant JITO_POOL =
        0x048a3e08c3b495be17f45427d89bec5b80c7e2695c1864d76743db39bed346d6;

    /// Forbidden CPI targets (never restake, never stake-pool deposit/withdraw).
    bytes32 internal constant STAKE_POOL_PROGRAM =
        0x06814ed4caf68a174672fdac86031a63e84ea15efa1d44b72293f6dbdb001650; // SPoo1Ku8…
    bytes32 internal constant INTERCEPTOR =
        0x4222d786aaf1f77b6ca6ff87ae9d7df5a64792e98148418c33e1a0bd3fd7fa32; // 5TAiuAh3…
    bytes32 internal constant VAULT_PROGRAM =
        0x07529703e9d148240ded13d75358ce6528786d41ddbbc372760bb2a17450ff7d; // Vau1t6sL…
    bytes32 internal constant RESTAKING_PROGRAM =
        0x0650c480c520386d2e86ae0ecf74898b8e56ea34e727fd46b0d516f75461ca51; // RestkWeA…

    /// LayerZero Solana mainnet (eid 30168). Peer on HyperEVM is the OApp **Store PDA**,
    /// not the program id. DVN trio matches EVM: Labs + Horizen + Canary. Not Nethermind.
    /// @dev 76y77prsiCMvXMjuoZ5VRrhG5qYBrUMYTE5WgHqgjEn6
    bytes32 internal constant LZ_ENDPOINT_SOLANA =
        0x5aad76da514b6e1dcf11037e904dac3d375f525c9fbafcb19507b78907d8c18b;
    /// @dev 7a4WjyR8VZ7yZz5XJAKm39BUGn5iT9CKcv2pmG9tdXVH
    bytes32 internal constant LZ_ULN_SOLANA =
        0x619e429a1de67854bd455ee6643f568d6236cde8e9442a3abf029f016faae630;
    /// @dev 6doghB248px58JSSwG4qejQ46kFMW4AMj7vzJnWZHNZn
    bytes32 internal constant LZ_EXECUTOR_PROGRAM_SOLANA =
        0x53b82142f29732a56fb6c88fa402fd18a1ddca13741d6ba73d3fcf9ae81021c1;
    /// @dev AwrbHeCyniXaQhiJZkLhgWdUCteeWSGaSN1sTfLiY7xK
    bytes32 internal constant LZ_EXECUTOR_PDA_SOLANA =
        0x93c69e71c758b9a308dd542e1c7f6edbf4b2342a6b74a0ce955ea97675f85528;
    /// @dev 4VDjp6XQaxoZf5RGwiPU9NR1EXSZn2TP4ATMmiSzLfhb
    bytes32 internal constant DVN_LABS_SOLANA =
        0x33cdb9fb56d28a2f028cbb36c254a7d54c92f0419b53e44ddcc0a5c373f854f2;
    /// @dev HR9NQKK1ynW9NzgdM37dU5CBtqRHTukmbMKS7qkwSkHX
    bytes32 internal constant DVN_HORIZEN_SOLANA =
        0xf3ea64a20ecedc882c28a0ba115a3a338ce2bb0d746d123c5b4abbdbead761f2;
    /// @dev 7jMeX5mzXnSSKYd8DxBDP4xMnkNFZZZm5W28FWUTbwU3
    bytes32 internal constant DVN_CANARY_SOLANA =
        0x63ffdc6cb15c7f9c8d1036120182e4f48f9ce5919dda1defd954f8655097bdc8;
    /// @dev GPjyWr8vCotGuFubDpTxDxy9Vj1ZeEN4F2dwRmFiaGab — exited EVM DVN role; never the Solana stack either.
    bytes32 internal constant DVN_NETHERMIND_SOLANA =
        0xe4b2ac493a2dd060e66df3200996f7050bced9c0a465bedc1261272a1bb24330;

    uint32 internal constant DEST_EID = 30367; // HyperEVM
    uint32 internal constant SOURCE_EID = 30168; // Solana

    error ForbiddenProgram();
    error CannotHarvestInner();
    error BadSolanaDvn();
    error NotSolanaPeer();

    function isForbiddenProgram(bytes32 program) internal pure returns (bool) {
        return program == STAKE_POOL_PROGRAM || program == INTERCEPTOR || program == VAULT_PROGRAM
            || program == RESTAKING_PROGRAM;
    }

    function requireAllowedProgram(bytes32 program) internal pure {
        if (isForbiddenProgram(program)) revert ForbiddenProgram();
    }

    /// @dev Side-token airdrop ATAs on the PDA (e.g. a future JTO-style snapshot).
    ///      Never this path for JitoSOL — that is rate skim only.
    function requireHarvestOther(bytes32 mint) internal pure {
        if (mint == JITO_MINT || mint == bytes32(0)) revert CannotHarvestInner();
    }

    function isSolanaRequiredDvn(bytes32 dvn) internal pure returns (bool) {
        return dvn == DVN_LABS_SOLANA || dvn == DVN_HORIZEN_SOLANA || dvn == DVN_CANARY_SOLANA;
    }

    function requireSolanaDvn(bytes32 dvn) internal pure {
        if (dvn == DVN_NETHERMIND_SOLANA || !isSolanaRequiredDvn(dvn)) revert BadSolanaDvn();
    }

    /// @dev HyperEVM peer for Solana is a Store PDA (32-byte, not left-padded).
    function requireSolanaPeer(bytes32 peer) internal pure {
        if (peer == bytes32(0) || bytes12(peer) == 0) revert NotSolanaPeer();
    }
}
