// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVVVStaking} from "../interfaces/IVVVStaking.sol";

/// @notice Verification-stage Position Adapter for Venice VVV staking.
/// @dev Framework only. Live Base StakingV2 is a UUPS proxy and its unstake path
///      is cooldown-based; this adapter intentionally does not pretend withdrawal is instant.
contract VVVStakingAdapter {
    using SafeERC20 for IERC20;

    error NotVault();
    error RateJump();
    error InvalidConfig();

    IERC20 public immutable VVV;
    IVVVStaking public immutable STAKING;
    address public immutable vault;

    uint256 public lastObservedRate;
    uint256 public maxRateChangeBps = 500; // 5%; proposal only
    bool public depositsEnabled = true;

    constructor(address vvv_, address staking_, address vault_) {
        if (vvv_ == address(0) || staking_ == address(0) || vault_ == address(0)) revert InvalidConfig();
        VVV = IERC20(vvv_);
        STAKING = IVVVStaking(staking_);
        vault = vault_;
    }

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault();
        _;
    }

    /// @notice Realized NAV only: staked receipt + VVV already sitting here.
    ///         pendingRewards are not liabilities until harvest() claims them.
    function totalAssets() public view returns (uint256) {
        return STAKING.balanceOf(address(this)) + VVV.balanceOf(address(this));
    }

    function emissionRatePerSecond() external view returns (uint256) {
        return STAKING.emissionRatePerSecond();
    }

    function cooldownState() external view returns (uint256 cooldownEnd, uint256 cooldownAmount) {
        (, cooldownEnd, cooldownAmount) = STAKING.stakes(address(this));
    }

    function cooldownDuration() external view returns (uint256) {
        return STAKING.cooldownDuration();
    }

    function deposit(uint256 amount) external onlyVault {
        if (!depositsEnabled) revert InvalidConfig();
        VVV.forceApprove(address(STAKING), amount);
        STAKING.stake(address(this), amount);
    }

    function harvest() external onlyVault returns (uint256 realizedReward) {
        uint256 beforeBal = VVV.balanceOf(address(this));
        STAKING.claim();
        uint256 afterBal = VVV.balanceOf(address(this));
        realizedReward = afterBal - beforeBal;
    }

    /// @notice Start the live 7-day-style cooldown path (exact duration is read from the contract).
    function initiateWithdraw(uint256 amount) external onlyVault {
        STAKING.initiateUnstake(amount);
    }

    /// @notice Finalize an already completed cooldown. Pays the unstake delta only;
    ///         previously harvested VVV stays until the vault sweeps it.
    function finalizeWithdraw(address recipient) external onlyVault {
        uint256 before = VVV.balanceOf(address(this));
        STAKING.finalizeUnstake();
        uint256 got = VVV.balanceOf(address(this)) - before;
        if (got != 0) VVV.safeTransfer(recipient, got);
    }

    function verifyHealth(uint256 liabilities) external view returns (bool) {
        return totalAssets() >= liabilities;
    }

    /// @dev Framework breaker only; final production accounting must use verified source semantics.
    function setRateObservation(uint256 newRate) external onlyVault {
        if (lastObservedRate != 0) {
            uint256 diff = newRate > lastObservedRate
                ? newRate - lastObservedRate
                : lastObservedRate - newRate;
            if (diff * 10_000 > lastObservedRate * maxRateChangeBps) revert RateJump();
        }
        lastObservedRate = newRate;
    }

    function setDepositsEnabled(bool enabled) external onlyVault {
        depositsEnabled = enabled;
    }
}
