// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Per-series books are in *underlying* assets (USDM/USDV).
///         The bag is ERC-4626 shares (sUSDM/sUSDV). Yield is share-price, not rebase,
///         so harvest skims surplus shares — never redeem (cooldown).
contract EscrowVault {
    using SafeERC20 for IERC20;

    address public immutable factory;
    IERC4626 public immutable vaultToken;
    address public feeRecipient;

    mapping(bytes32 => uint256) public collateralOf; // underlying assets
    mapping(bytes32 => uint256) public escrowOf; // underlying assets
    uint256 public totalBooked; // underlying assets

    error NotFactory();
    error Shortfall();
    error Insufficient();

    event Locked(bytes32 indexed seriesId, bool collateral, uint256 assets);
    event Released(bytes32 indexed seriesId, bool collateral, address to, uint256 assets);
    event Harvested(bytes32 indexed seriesId, uint256 shares);

    constructor(address factory_, IERC4626 vaultToken_, address feeRecipient_) {
        factory = factory_;
        vaultToken = vaultToken_;
        feeRecipient = feeRecipient_;
    }

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    function credit(bytes32 seriesId, uint256 assets, bool collateral) external onlyFactory {
        uint256 held = vaultToken.convertToAssets(vaultToken.balanceOf(address(this)));
        if (held + 1 < totalBooked + assets) revert Shortfall();
        if (collateral) collateralOf[seriesId] += assets;
        else escrowOf[seriesId] += assets;
        totalBooked += assets;
        emit Locked(seriesId, collateral, assets);
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
        totalBooked -= assets;
        uint256 shares = _sharesCeil(assets);
        uint256 bal = vaultToken.balanceOf(address(this));
        if (shares > bal) shares = bal;
        IERC20(address(vaultToken)).safeTransfer(to, shares);
        emit Released(seriesId, collateral, to, assets);
    }

    /// @dev Skim share-price surplus as shares. Does not unwrap (sUSDM cooldown).
    function harvest(bytes32 seriesId) external onlyFactory returns (uint256 extraShares) {
        uint256 bal = vaultToken.balanceOf(address(this));
        uint256 keep = _sharesCeil(totalBooked);
        if (bal <= keep) return 0;
        extraShares = bal - keep;
        IERC20(address(vaultToken)).safeTransfer(feeRecipient, extraShares);
        emit Harvested(seriesId, extraShares);
    }

    function setFeeRecipient(address n) external onlyFactory {
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
