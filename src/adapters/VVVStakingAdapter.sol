// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVVVStaking} from "../interfaces/IVVVStaking.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Verification-stage Position Adapter for Venice VVV staking.
/// @dev Framework only. Confirm the live Base ABI, ownership/upgrade path,
///      sVVV representation and staking semantics before deployment.
contract VVVStakingAdapter {
    error NotVault();
    error RateJump();
    error InvalidConfig();

    IERC20Like public immutable VVV;
    IVVVStaking public immutable STAKING;
    address public immutable vault;

    uint256 public lastObservedRate;
    uint256 public maxRateChangeBps = 500; // 5%; proposal only
    bool public depositsEnabled = true;

    constructor(address vvv_, address staking_, address vault_) {
        if (vvv_ == address(0) || staking_ == address(0) || vault_ == address(0)) revert InvalidConfig();
        VVV = IERC20Like(vvv_);
        STAKING = IVVVStaking(staking_);
        vault = vault_;
    }

    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault();
        _;
    }

    function totalAssets() public view returns (uint256) {
        return STAKING.stakedBalance(address(this)) + STAKING.pendingRewards(address(this));
    }

    function emissionRatePerSecond() external view returns (uint256) {
        return STAKING.emissionRatePerSecond();
    }

    function deposit(uint256 amount) external onlyVault {
        if (!depositsEnabled) revert InvalidConfig();
        VVV.approve(address(STAKING), amount);
        STAKING.stake(amount);
    }

    function harvest() external onlyVault returns (uint256 realizedReward) {
        uint256 beforeBal = VVV.balanceOf(address(this));
        STAKING.claimRewards();
        uint256 afterBal = VVV.balanceOf(address(this));
        realizedReward = afterBal - beforeBal;
    }

    function withdraw(uint256 amount, address recipient) external onlyVault {
        STAKING.unstake(amount);
        VVV.transfer(recipient, amount);
    }

    function verifyHealth(uint256 liabilities) external view returns (bool) {
        return totalAssets() >= liabilities;
    }

    /// @dev Framework breaker only; final accounting must use verified source semantics.
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
