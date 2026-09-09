// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IHevAdapter} from "./interfaces/IHevAdapter.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {IHevStrategy} from "./interfaces/IHevStrategy.sol";
import {IVirtualRewarder} from "./interfaces/IVirtualRewarder.sol";
import {HyperEVMAddresses} from "./config/HyperEVMAddresses.sol";

/**
 * @title HevAdapter
 * @notice Production-oriented adapter: attach/detach via Voter managed NFT path,
 *         pending via HEV.getLockedRewardsBalance (NEST share). No public HYPE claim yet.
 *
 * @dev LIVE ABI (confirmed 2026-09-03 HyperEVM mainnet):
 * 1) Prefer NestVault createLockFor(..., managedTokenIdForAttach_=1) for atomic lock+attach
 * 2) Fallback: Voter.attachToManagedNFT(tokenId, HEV_MANAGED_TOKEN_ID) // 0xca82240d
 * 3) Exit: Voter.dettachFromManagedNFT(tokenId) // 0x12dd7200 intentional double-t
 * 4) Claim: VR.harvest strategy-only; user pending = getLockedRewardsBalance (NEST).
 *    MEGAHYPE not launched — sweepResidualHype only forwards stray HYPE ERC20 on this adapter.
 *
 * Withdraw timing (NestVault owns policy — see docs/WITHDRAW_WINDOWS.md):
 * - Do not call withdrawVeNFT on every redeem; onDettach resets lock end ≈ now+26w
 * - HEV.detachmentLockDuration is 4 days on-chain (we do not control HEV).
 *   NestVault gates dettachForLiquidity at 8 days because the NEST reward cycle is 7 days.
 * - Attached getNftState amount/end are zero — vault tracks nestPrincipal
 */
contract HevAdapter is IHevAdapter, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Vault-side gate (8 days). HEV itself still allows dettach after 4 days.
    uint256 public constant DETACHMENT_LOCK_DURATION = 8 days;

    IVotingEscrow public immutable veNEST;
    IVoter public immutable voter;
    IERC20 public immutable hypeToken;
    address public vault;
    address public virtualRewarder;
    address public veNestDistributor;
    address public hevStrategy;
    uint256 public managedTokenId;

    mapping(uint256 => bool) public deposited;
    uint256 public depositedCount;

    error OnlyVault();
    error NotDeposited();
    error AlreadyDeposited();
    error ZeroVault();
    error VaultChangeWhileDeposited();

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    constructor(
        address _veNEST,
        address _voter,
        address _hypeToken,
        address _vault,
        address _virtualRewarder,
        address _veNestDistributor,
        uint256 _managedTokenId
    ) Ownable(msg.sender) {
        veNEST = IVotingEscrow(_veNEST);
        voter = IVoter(_voter);
        hypeToken = IERC20(_hypeToken);
        vault = _vault;
        virtualRewarder = _virtualRewarder;
        veNestDistributor = _veNestDistributor;
        managedTokenId = _managedTokenId;
        hevStrategy = HyperEVMAddresses.HEV_STRATEGY;
    }

    function setVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert ZeroVault();
        if (depositedCount != 0) revert VaultChangeWhileDeposited();
        vault = _vault;
    }

    function setHevStrategy(address _hevStrategy) external onlyOwner {
        hevStrategy = _hevStrategy;
    }

    /// @inheritdoc IHevAdapter
    function depositVeNFT(uint256 tokenId) external onlyVault {
        if (deposited[tokenId]) revert AlreadyDeposited();
        // Idempotent: NestVault may already have attached via createLockFor(..., managedId=1).
        IVotingEscrow.TokenState memory state = veNEST.getNftState(tokenId);
        if (!state.isAttached) {
            voter.attachToManagedNFT(tokenId, managedTokenId);
        }
        deposited[tokenId] = true;
        depositedCount += 1;
    }

    /// @inheritdoc IHevAdapter
    /// @dev Caller (NestVault) must enforce 8d detachment gate + post-dettach 26w accounting.
    function withdrawVeNFT(uint256 tokenId) external onlyVault {
        if (!deposited[tokenId]) revert NotDeposited();
        IVotingEscrow.TokenState memory state = veNEST.getNftState(tokenId);
        if (state.isAttached) {
            voter.dettachFromManagedNFT(tokenId);
        }
        deposited[tokenId] = false;
        depositedCount -= 1;
    }

    /// @inheritdoc IHevAdapter
    /// @dev No user-facing Nest liquid HYPE / MEGAHYPE ABI. VR.harvest is strategy-only.
    ///      Forwards any HYPE ERC20 sitting on this adapter (usually zero).
    function sweepResidualHype(
        uint256[] calldata,
        /* tokenIds */
        address recipient
    )
        external
        onlyVault
        returns (uint256 amountClaimed)
    {
        // Confirmed absent: virtualRewarder.getReward(address)
        // Confirmed strategy-only: virtualRewarder.harvest(tokenId)
        // Confirmed operator (managed NFT): hevStrategy.claimRewards / claimBribes — not per-user
        // Pending NEST share remains locked until dettach — see pendingLockedNestShare
        if (virtualRewarder != address(0)) {
            // no-op by design until Nest publishes a user liquid-HYPE claim surface
            virtualRewarder;
        }
        amountClaimed = hypeToken.balanceOf(address(this));
        if (amountClaimed > 0) {
            hypeToken.safeTransfer(recipient, amountClaimed);
        }
    }

    /// @notice Pending locked rewards share (NEST-denominated via HEV), not liquid HYPE.
    function pendingLockedNestShare(uint256 tokenId) external view returns (uint256) {
        if (hevStrategy != address(0)) {
            return IHevStrategy(hevStrategy).getLockedRewardsBalance(tokenId);
        }
        if (virtualRewarder != address(0)) {
            return IVirtualRewarder(virtualRewarder).calculateAvailableRewardsAmount(tokenId);
        }
        return hypeToken.balanceOf(address(this));
    }

    /// @notice Convenience defaults matching HyperEVMAddresses library constants.
    function officialDefaults()
        external
        pure
        returns (address hev, uint256 mid, address rewarder, address distributor, address voterAddr)
    {
        return (
            HyperEVMAddresses.HEV_STRATEGY,
            HyperEVMAddresses.HEV_MANAGED_TOKEN_ID,
            HyperEVMAddresses.VIRTUAL_REWARDER,
            HyperEVMAddresses.VE_NEST_DISTRIBUTOR,
            HyperEVMAddresses.VOTER
        );
    }
}
