// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title HKaito
/// @notice HyperEVM 1:1 receipt for sKAITO locked in the Base SKaitoVault.
///         Mint only against a Base depositId. Burn to request sKAITO release
///         on Base. No KAITO <-> sKAITO conversion lives here.
contract HKaito is ERC20, ERC20Permit, Ownable2Step, Pausable, ReentrancyGuard {
    address public relayer;
    address public guardian;
    uint256 public redeemNonce;

    mapping(bytes32 => bool) public minted;

    event RelayerUpdated(address indexed oldRelayer, address indexed newRelayer);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event Minted(address indexed user, uint256 amount, bytes32 indexed depositId);
    event RedeemRequested(address indexed user, uint256 amount, bytes32 indexed redeemId, uint256 nonce);

    error ZeroAddress();
    error ZeroAmount();
    error AlreadyMinted();
    error NotRelayer();
    error NotGuardian();

    modifier onlyRelayer() {
        if (msg.sender != relayer) revert NotRelayer();
        _;
    }

    constructor(address _relayer, address _guardian)
        ERC20("Hyperleaf sKAITO", "hKAITO")
        ERC20Permit("Hyperleaf sKAITO")
        Ownable(msg.sender)
    {
        if (_relayer == address(0) || _guardian == address(0)) revert ZeroAddress();
        relayer = _relayer;
        guardian = _guardian;
    }

    function setRelayer(address _relayer) external onlyOwner {
        if (_relayer == address(0)) revert ZeroAddress();
        emit RelayerUpdated(relayer, _relayer);
        relayer = _relayer;
    }

    function setGuardian(address _guardian) external onlyOwner {
        if (_guardian == address(0)) revert ZeroAddress();
        emit GuardianUpdated(guardian, _guardian);
        guardian = _guardian;
    }

    function pause() external {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardian();
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount, bytes32 depositId) external onlyRelayer whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (minted[depositId]) revert AlreadyMinted();
        minted[depositId] = true;
        _mint(to, amount);
        emit Minted(to, amount, depositId);
    }

    function redeem(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        uint256 nonce = ++redeemNonce;
        bytes32 redeemId = keccak256(abi.encode(block.chainid, address(this), msg.sender, amount, nonce));
        _burn(msg.sender, amount);
        emit RedeemRequested(msg.sender, amount, redeemId, nonce);
    }
}
