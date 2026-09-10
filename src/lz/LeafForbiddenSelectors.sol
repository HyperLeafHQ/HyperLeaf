// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Single denylist for poke/claim selectors. Adapter, inbound, queue, and
///      omnichain holder must use this. A fork lets a redeem selector through
///      one path and not the other.
library LeafForbiddenSelectors {
    function forbidden(bytes4 s) internal pure returns (bool) {
        return exit(s) || lbtc(s);
    }

    function exit(bytes4 s) internal pure returns (bool) {
        return s == bytes4(0x1e9a6950) // redeem(address,uint256)
            || s == bytes4(0xeab52318) // claimRewardsAndRedeem(address,uint256,uint256) — Avantis
            || s == bytes4(0x787a08a6) // cooldown()
            || s == bytes4(0xb460af94) // withdraw(uint256,address,address)
            || s == bytes4(0xba087652) // redeem(uint256,address,address)
            || s == bytes4(0x9343d9e1) // cooldownShares(uint256)
            || s == bytes4(0xcdac52ed) // cooldownAssets(uint256)
            || s == bytes4(0x1e83409a) // claim(address)
            || s == bytes4(0x9ad82aa0) // queueRedeem
            || s == bytes4(0x50b3f984) // queueWithdraw
            || s == bytes4(0x38248a0c) // completeWithdrawal(bool) — sWBERA 7d NFT
            || s == bytes4(0x06866fdc) // completeWithdrawal(bool,uint256)
            || s == bytes4(0x1b0aed2c) // cancelQueuedWithdrawal (vault)
            || s == bytes4(0x041d5408) // cancelQueuedWithdrawal()
            || s == bytes4(0xc9d2ff9d) // requestUnlock(uint256) — BENQI sAVAX 15d
            || s == bytes4(0x2e1a7d4d) // withdraw(uint256) — BENQI claim AVAX / SOON 90d unlock
            || s == bytes4(0x1338736f) // lock(uint256,uint256) — SOON occupancy
            || s == bytes4(0x6e553f65) // deposit(uint256,address) — ERC-4626
            || s == bytes4(0x94bf804d) // mint(uint256,address)
            || s == bytes4(0x250201db) // cooldownOnBehalfOf(address) — Umbrella
            || s == bytes4(0x397a1b28) // requestWithdraw(address,uint256) — ether.fi
            || s == bytes4(0x0efe6a8b) // deposit(address,uint256,uint256) — sETHFI teller
            || s == bytes4(0x1d7d4ebc) // KING merkle claim
            || s == bytes4(0x2e7ba6ef) // ETHFI/EIGEN merkle claim
            || s == bytes4(0x745400c9) // requestWithdraw(uint256) — Lista 7d
            || s == bytes4(0xb13acedd) // claimWithdraw(uint256) — Lista / ether.fi
            || s == bytes4(0x9a53d5af) // claimWithdrawFor(address,uint256)
            || s == bytes4(0xfd92bff2) // instantWithdraw(uint256) — Lista
            || s == bytes4(0xd0e30db0) // deposit() — Lista native BNB
            || s == bytes4(0x5bcb2fc6) // submit() — BENQI stake AVAX
            || s == bytes4(0xa1903eab) // submit(address)
            || s == bytes4(0xdb006a75) // redeem(uint256) — BENQI unlock claim
            || s == bytes4(0x819bfd9e) // cancelUnlock(uint256)
            || s == bytes4(0xda276040); // cooldown(uint256)
    }

    function lbtc(bytes4 s) internal pure returns (bool) {
        return s == bytes4(0x42966c68) // burn(uint256)
            || s == bytes4(0xbcf64e05) // burn(uint256,bytes32)
            || s == bytes4(0x6bc63893) // mint(bytes,bytes)
            || s == bytes4(0x8340f549) // deposit(address,address,uint256)
            || s == bytes4(0xe5c1bf6e); // redeem(bytes,bytes)
    }
}
