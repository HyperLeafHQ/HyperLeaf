// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISPOL {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface ISPOLController {
    function convertPOLtoSPOL(uint256 amountPOL) external view returns (uint256);
    function convertSPOLtoPOL(uint256 amountSPOL) external view returns (uint256);
    function totalsPOLBalance() external view returns (uint256);
    function polToken() external view returns (address);
    function sPOLToken() external view returns (address);
    function paused() external view returns (bool);
}
