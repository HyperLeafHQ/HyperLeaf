// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract LeafYieldFee {
    using SafeERC20 for IERC20;

    uint16 public constant YIELD_FEE_BPS = 100;
    uint16 public constant BPS_DENOMINATOR = 10_000;

    address public feeRecipient;
    uint256 public lastAccounted;
    mapping(address token => uint256 accounted) public lastAccountedToken;

    event FeeRecipientUpdated(address indexed recipient);
    event YieldHarvested(address indexed token, uint256 yieldAmount, uint256 fee);

    error FeeRecipientZero();

    function _initFee(address recipient) internal {
        if (recipient == address(0)) revert FeeRecipientZero();
        feeRecipient = recipient;
    }

    function _setFeeRecipient(address recipient) internal {
        if (recipient == address(0)) revert FeeRecipientZero();
        feeRecipient = recipient;
        emit FeeRecipientUpdated(recipient);
    }

    function _accountDeposit(uint256 got) internal {
        lastAccounted += got;
    }

    function _syncAccounted(IERC20 token, uint256 reserved) internal {
        uint256 bal = token.balanceOf(address(this));
        lastAccounted = bal > reserved ? bal - reserved : 0;
    }

    function _harvestInner(IERC20 token, uint256 reserved) internal returns (uint256 fee) {
        uint256 bal = token.balanceOf(address(this));
        if (bal <= reserved) {
            lastAccounted = 0;
            return 0;
        }
        uint256 free = bal - reserved;
        if (free <= lastAccounted) return 0;
        uint256 y = free - lastAccounted;
        fee = (y * YIELD_FEE_BPS) / BPS_DENOMINATOR;
        if (fee > 0) {
            token.safeTransfer(feeRecipient, fee);
            free -= fee;
        }
        lastAccounted = free;
        emit YieldHarvested(address(token), y, fee);
    }

    function _harvestOther(IERC20 token) internal returns (uint256 fee) {
        uint256 bal = token.balanceOf(address(this));
        uint256 last = lastAccountedToken[address(token)];
        if (bal <= last) return 0;
        uint256 y = bal - last;
        fee = (y * YIELD_FEE_BPS) / BPS_DENOMINATOR;
        if (fee > 0) token.safeTransfer(feeRecipient, fee);
        lastAccountedToken[address(token)] = token.balanceOf(address(this));
        emit YieldHarvested(address(token), y, fee);
    }

    function _assetsForShares(IERC20 token, uint256 shares, uint256 totalShares, uint256 reserved)
        internal
        view
        returns (uint256)
    {
        if (shares == 0 || totalShares == 0) return 0;
        uint256 bal = token.balanceOf(address(this));
        uint256 free = bal > reserved ? bal - reserved : 0;
        return (shares * free) / totalShares;
    }
}
