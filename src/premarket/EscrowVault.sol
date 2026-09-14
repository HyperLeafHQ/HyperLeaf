// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Users pay *underlying* (USDM). This vault wraps to ERC-4626 shares (sUSDM)
///         and books NAV. Yield is share-price: harvest skims surplus shares per series.
///         A falling rate cannot freeze other series — books and shares are isolated.
contract EscrowVault {
    using SafeERC20 for IERC20;

    address public immutable factory;
    IERC4626 public immutable vaultToken;
    IERC20 public immutable underlying;
    address public feeRecipient;

    mapping(bytes32 => uint256) public collateralOf; // underlying assets
    mapping(bytes32 => uint256) public escrowOf; // underlying assets
    mapping(bytes32 => uint256) public sharesOf; // 4626 shares isolated per series

    error NotFactory();
    error Shortfall();
    error Insufficient();
    error Slippage();
    error Zero();

    event Locked(bytes32 indexed seriesId, bool collateral, uint256 assets, uint256 shares);
    event Released(bytes32 indexed seriesId, bool collateral, address to, uint256 assets, uint256 shares);
    event Harvested(bytes32 indexed seriesId, uint256 shares);

    constructor(address factory_, IERC4626 vaultToken_, address feeRecipient_) {
        factory = factory_;
        vaultToken = vaultToken_;
        underlying = IERC20(vaultToken_.asset());
        feeRecipient = feeRecipient_;
        if (address(underlying) == address(0) || feeRecipient_ == address(0)) revert Zero();
    }

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    /// @dev `assets` of underlying must already sit on this vault. Wrap to sUSDM and book this series.
    function wrapAndCredit(bytes32 seriesId, uint256 assets, bool collateral, uint256 maxShares)
        external
        onlyFactory
        returns (uint256 shares)
    {
        if (assets == 0) revert Zero();
        underlying.forceApprove(address(vaultToken), assets);
        shares = vaultToken.deposit(assets, address(this));
        if (shares > maxShares) revert Slippage();
        if (vaultToken.convertToAssets(shares) + 1 < assets) revert Shortfall();
        if (collateral) collateralOf[seriesId] += assets;
        else escrowOf[seriesId] += assets;
        sharesOf[seriesId] += shares;
        emit Locked(seriesId, collateral, assets, shares);
    }

    function release(bytes32 seriesId, address to, uint256 assets, bool collateral) external onlyFactory {
        if (collateral) {
            if (collateralOf[seriesId] < assets) revert Insufficient();
            unchecked {
                collateralOf[seriesId] -= assets;
            }
        } else {
            if (escrowOf[seriesId] < assets) revert Insufficient();
            unchecked {
                escrowOf[seriesId] -= assets;
            }
        }
        uint256 shares = _sharesCeil(assets);
        uint256 have = sharesOf[seriesId];
        if (shares > have) shares = have;
        sharesOf[seriesId] = have - shares;
        if (shares > 0) IERC20(address(vaultToken)).safeTransfer(to, shares);
        emit Released(seriesId, collateral, to, assets, shares);
    }

    /// @dev Skim this series' share-price surplus. Does not unwrap (sUSDM cooldown).
    function harvest(bytes32 seriesId) external onlyFactory returns (uint256 extraShares) {
        uint256 booked = collateralOf[seriesId] + escrowOf[seriesId];
        uint256 keep = _sharesCeil(booked);
        uint256 have = sharesOf[seriesId];
        if (have <= keep) return 0;
        extraShares = have - keep;
        sharesOf[seriesId] = keep;
        IERC20(address(vaultToken)).safeTransfer(feeRecipient, extraShares);
        emit Harvested(seriesId, extraShares);
    }

    function setFeeRecipient(address n) external onlyFactory {
        if (n == address(0)) revert Zero();
        feeRecipient = n;
    }

    function sharesCeil(uint256 assets) external view returns (uint256) {
        return _sharesCeil(assets);
    }

    function _sharesCeil(uint256 assets) internal view returns (uint256 s) {
        if (assets == 0) return 0;
        s = vaultToken.convertToShares(assets);
        if (vaultToken.convertToAssets(s) < assets) s += 1;
    }
}
