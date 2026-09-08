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

    error ForbiddenProgram();
    error CannotHarvestInner();

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
}
