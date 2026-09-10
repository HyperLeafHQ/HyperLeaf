// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hB3 pins. Base only. stakeFor(lockbox, amt). Principal then sits in
///         EOA 0x8D06 — not a contract lock.
///         WIN is not a token. upside.win queues B3 as delayed withdrawals on
///         0xe69b (Base 8453, explorer.b3.fun/base is their Base indexer).
///         Live claim tx 0x087ce4a0: claimDelayedWithdrawal(5) paid 252.67 B3
///         to the stored recipient, Request ID 1431 in the event. Enable only
///         after a lockbox-as-user request pays the lockbox, not an EOA.
library LeafB3Policy {
    address internal constant B3 = 0xB3B32F9f8827D4634fE7d973Fa1034Ec9fdDB3B3;
    address internal constant STAKE = 0x18541C6D032d48E8cE735939a6147A6A5949216B;
    address internal constant STAKE_IMPL = 0x393B0c48eF44FfD6C22470bC96C6f382C89D682f;
    address internal constant CUSTODY = 0x8D06628251489963f9603Da96BaF987Dd08f5097;
    /// @dev stakeFor(address,uint256) — live tx 0x7ebe5e08…
    bytes4 internal constant STAKE_FOR = 0x2ee40908;
    /// @dev upside.win delayed B3. Impl 0x13582765… treasury = CUSTODY.
    address internal constant CLAIM = 0xe69Bc02DC0C4c6dAc306fFDdD2ebd4cf470F0764;
    address internal constant CLAIM_IMPL = 0x135827651431fA164fD80a97D5f08EA728803099;
    bytes4 internal constant CLAIM_DELAYED_WITHDRAWAL = 0xf41ba29c;
    address internal constant WIN = address(0);

    uint256 internal constant MIN_STAKE = 50 ether; // BSMNT FAQ
    uint32 internal constant UNSTAKE_COOLDOWN = 45 days;

    error WrongInner();
    error WrongStake();
    error ClaimUnset();
    error UnstakeForbidden();
    error WrongChain();

    function requireBase(uint256 chainId) internal pure {
        if (chainId != 8453) revert WrongChain();
    }

    function requireLive(address b3, address stake) internal pure {
        if (b3 != B3) revert WrongInner();
        if (stake != STAKE) revert WrongStake();
    }

    function requireClaimSet(address claim) internal pure {
        if (claim == address(0)) revert ClaimUnset();
    }

    /// @dev ERC20StakingUpgradeable exit family. Never poke these.
    function isUnstake(bytes4 s) internal pure returns (bool) {
        return s == bytes4(0x2e17de78) // unstake(uint256)
            || s == bytes4(0x7c0696e8) // instantUnstake(uint256)
            || s == bytes4(0xa3dad5e8) // instantUnstakeFor(address,address,uint256)
            || s == bytes4(0xf2e8c464) // instantUnstakeTo(uint256,address)
            || s == bytes4(0xf95e4ae8) // requestDelayedUnstake(uint256)
            || s == bytes4(0x9df2424a) // requestDelayedUnstakeFor(address,uint256)
            || s == bytes4(0x6866c05e) // requestDelayedUnstakeTo(uint256,address)
            || s == bytes4(0xedb46a1b) // claimDelayedUnstake(uint256)
            || s == bytes4(0x5631aaf8) // claimDelayedUnstakeFor(address,uint256)
            || s == bytes4(0x2b187b2b) // cancelUnstake(uint256)
            || s == bytes4(0xdb2e21bc); // emergencyWithdraw()
    }
}
