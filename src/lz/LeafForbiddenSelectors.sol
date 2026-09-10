// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Single denylist for poke/claim selectors. Adapter, inbound, queue, and
///      omnichain holder must use this. A fork lets a redeem selector through
///      one path and not the other.
library LeafForbiddenSelectors {
    function forbidden(bytes4 s) internal pure returns (bool) {
        return exit(s) || lbtc(s) || spol(s) || hertz(s) || hbarx(s) || sff(s);
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
            || s == bytes4(0x2e7ba6ef); // ETHFI/EIGEN merkle claim
    }

    /// @dev Official sPOLController mutating paths. convertSPOLtoPOL is view; still
    ///      listed so a poke cannot be pointed at it. sellSPOL queues the 80-checkpoint
    ///      unbond on the lockbox — that would freeze the vault.
    function spol(bytes4 s) internal pure returns (bool) {
        return s == bytes4(0xff8aaf7a) // convertSPOLtoPOL(uint256) view
            || s == bytes4(0xc356a582) // convertPOLtoSPOL(uint256) view
            || s == bytes4(0xbb7914a3) // buySPOL(uint256)
            || s == bytes4(0xb6722163) // buySPOL(uint256,uint16)
            || s == bytes4(0x4d4778a1) // buySPOLPermit(...)
            || s == bytes4(0x27bbe03d) // buySPOLPermit(...,uint16,...)
            || s == bytes4(0xf57ccae9) // buySPOLWithDPOL(uint256,uint16)
            || s == bytes4(0x5d43011f) // sellSPOL(uint256)
            || s == bytes4(0x32f42f13) // sellSPOL(uint256,uint16)
            || s == bytes4(0xacc150d0) // sellSPOLPermit(...)
            || s == bytes4(0x1341248d) // sellSPOLPermit(...,uint16,...)
            || s == bytes4(0x61ad860b) // withdrawPOL()
            || s == bytes4(0x8ffcca07); // withdrawPOL(address)
    }

    function lbtc(bytes4 s) internal pure returns (bool) {
        return s == bytes4(0x42966c68) // burn(uint256)
            || s == bytes4(0xbcf64e05) // burn(uint256,bytes32)
            || s == bytes4(0x6bc63893) // mint(bytes,bytes)
            || s == bytes4(0x8340f549) // deposit(address,address,uint256)
            || s == bytes4(0xe5c1bf6e); // redeem(bytes,bytes)
    }

    /// @dev HertzFlow HLV. Lockbox only holds the ERC-20. Never poke deposit/withdraw
    ///      keepers or the token's Bank mint/burn/transferOut.
    function hertz(bytes4 s) internal pure returns (bool) {
        return s == bytes4(0xd6b8546b) // executeHlvDeposit(bytes32,(address[],address[],bytes[]))
            || s == bytes4(0x55ceeb84) // executeHlvWithdrawal(bytes32,(address[],address[],bytes[]))
            || s == bytes4(0xd0e30db0) // deposit()
            || s == bytes4(0x40c10f19) // mint(address,uint256)
            || s == bytes4(0x9dc29fac) // burn(address,uint256)
            || s == bytes4(0x078d3b79) // transferOut(address,address,uint256)
            || s == bytes4(0x2fb12605) // transferOut(address,address,uint256,bool)
            || s == bytes4(0xd443ca94); // transferOutNativeToken(address,uint256)
    }

    /// @dev Stader HBARX unstake. Lockbox never requests the 1-day HBAR unbond.
    function hbarx(bytes4 s) internal pure returns (bool) {
        return s == bytes4(0x745400c9) // requestWithdraw(uint256)
            || s == bytes4(0x2e17de78) // unstake(uint256)
            || s == bytes4(0x23095721); // requestUnstake(uint256)
    }

    /// @notice sFF cooldown is already in exit(). Do not add claimRewards(address,uint256)
    ///         0x9a99b4f0 — that is also the QUID poke. Only the on-behalf variant.
    function sff(bytes4 s) internal pure returns (bool) {
        return s == bytes4(0x20fb80b5); // claimRewardsOnBehalf(address,address,uint256)
    }
}
