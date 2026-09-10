// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Verification-stage interface aligned to Base StakingV2.
/// @dev Live implementation: 0xe37A7920dbc11253ac6d031C29f592f71B348DCA.
///      Re-verify ABI and storage layout before production deployment.
interface IVVVStaking {
    function stake(address recipient, uint256 amount) external;
    function initiateUnstake(uint256 amount) external;
    function finalizeUnstake() external;
    function claim() external;
    function claimAndStake() external;

    function balanceOf(address account) external view returns (uint256);
    function balanceOfUnlocked(address user) external view returns (uint256);
    function pendingRewards(address user) external view returns (uint256);
    function stakes(address user)
        external
        view
        returns (uint256 rewardDebt, uint256 cooldownEnd, uint256 cooldownAmount);
    function cooldownDuration() external view returns (uint256);
    function emissionRatePerSecond() external view returns (uint256);
    function accRewardPerShare() external view returns (uint256);
    function accRewardPerShareLocked() external view returns (uint256);
    function totalLockedStakedVVV() external view returns (uint256);
    function veniceEmissionsPercentage() external view returns (uint256);
    function veniceEmissionsPercentageWhenLocked() external view returns (uint256);
    function getDiemAmountOut(uint256 sVVVAmountToLock) external view returns (uint256);
    function lockedStakes(address user)
        external
        view
        returns (uint256 sVVVLockedAmount, uint256 outstandingDiemAmount);
    function diem() external view returns (address);
    function oracle() external view returns (address);
    function treasury() external view returns (address);
    function owner() external view returns (address);

    function proxiableUUID() external view returns (bytes32);
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
}
