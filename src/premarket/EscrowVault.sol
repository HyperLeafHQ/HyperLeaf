// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Per-series collateral C and payment R. Extra token balance is interest.
contract EscrowVault {
    using SafeERC20 for IERC20;

    address public immutable factory;
    IERC20 public immutable asset;
    address public feeRecipient;

    mapping(bytes32 => uint256) public collateralOf;
    mapping(bytes32 => uint256) public escrowOf;
    uint256 public totalPrincipal;

    error NotFactory();
    error Shortfall();
    error Insufficient();

    event Locked(bytes32 indexed seriesId, bool collateral, uint256 amount);
    event Released(bytes32 indexed seriesId, bool collateral, address to, uint256 amount);
    event Harvested(bytes32 indexed seriesId, uint256 amount);

    constructor(address factory_, IERC20 asset_, address feeRecipient_) {
        factory = factory_;
        asset = asset_;
        feeRecipient = feeRecipient_;
    }

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    function credit(bytes32 seriesId, uint256 got, bool collateral) external onlyFactory {
        uint256 bal = asset.balanceOf(address(this));
        if (bal < totalPrincipal + got) revert Shortfall();
        if (collateral) collateralOf[seriesId] += got;
        else escrowOf[seriesId] += got;
        totalPrincipal += got;
        emit Locked(seriesId, collateral, got);
    }

    function release(bytes32 seriesId, address to, uint256 amount, bool collateral) external onlyFactory {
        if (collateral) {
            if (collateralOf[seriesId] < amount) revert Insufficient();
            unchecked {
                collateralOf[seriesId] -= amount;
            }
        } else {
            if (escrowOf[seriesId] < amount) revert Insufficient();
            unchecked {
                escrowOf[seriesId] -= amount;
            }
        }
        totalPrincipal -= amount;
        asset.safeTransfer(to, amount);
        emit Released(seriesId, collateral, to, amount);
    }

    /// @dev Skim token balance above principal. 100% to feeRecipient.
    function harvest(bytes32 seriesId) external onlyFactory returns (uint256 extra) {
        uint256 bal = asset.balanceOf(address(this));
        if (bal <= totalPrincipal) return 0;
        extra = bal - totalPrincipal;
        asset.safeTransfer(feeRecipient, extra);
        emit Harvested(seriesId, extra);
    }

    function setFeeRecipient(address n) external onlyFactory {
        feeRecipient = n;
    }
}
