// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISPOL, ISPOLController} from "../interfaces/ISPOL.sol";

/// @title SPOLAdapter
/// @notice Read-only source-side accounting adapter for Polygon's canonical sPOL LST.
/// @dev Deliberately does not bridge, custody, mint hPOL, or assume instant redemption.
///      Cross-chain authentication belongs in a separate custody/message boundary.
contract SPOLAdapter {
    error ZeroAddress();
    error WrongSPOLToken();

    ISPOL public immutable sPOL;
    ISPOLController public immutable controller;
    address public immutable pol;

    constructor(address _sPOL, address _controller) {
        if (_sPOL == address(0) || _controller == address(0)) revert ZeroAddress();
        sPOL = ISPOL(_sPOL);
        controller = ISPOLController(_controller);
        pol = controller.polToken();
        if (controller.sPOLToken() != _sPOL) revert WrongSPOLToken();
    }

    /// @notice sPOL held by the strategy/custody account, denominated in POL.
    /// @dev Uses Polygon's canonical controller conversion function rather than a spot price.
    function totalAssets(address account) public view returns (uint256) {
        return controller.convertSPOLtoPOL(sPOL.balanceOf(account));
    }

    function totalShares(address account) external view returns (uint256) {
        return sPOL.balanceOf(account);
    }

    /// @notice Current POL value represented by one whole sPOL, scaled by 1e18.
    /// @dev Uses the sPOL token's own decimals rather than assuming 18 decimals.
    function exchangeRate1e18() external view returns (uint256) {
        uint256 supply = controller.totalsPOLBalance();
        if (supply == 0) return 1e18;
        uint256 unit = 10 ** uint256(sPOL.decimals());
        return controller.convertSPOLtoPOL(unit) * 1e18 / unit;
    }

    function previewDeposit(uint256 polAmount) external view returns (uint256) {
        return controller.convertPOLtoSPOL(polAmount);
    }

    function previewWithdraw(uint256 spolAmount) external view returns (uint256) {
        return controller.convertSPOLtoPOL(spolAmount);
    }

    function healthy(address account) external view returns (bool) {
        if (controller.paused()) return false;
        return sPOL.balanceOf(account) > 0;
    }
}
