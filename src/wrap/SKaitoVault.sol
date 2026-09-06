// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SKaitoVault
/// @notice Base-chain custody for official sKAITO. Users deposit sKAITO here;
///         a relayer mints 1:1 hKAITO on HyperEVM. Burns on HyperEVM are
///         released back as sKAITO on Base. This contract never wraps or
///         unwraps KAITO <-> sKAITO.
/// @dev Trusted relayer. Replay-protected by depositId / redeemId.
contract SKaitoVault is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @dev Official sKAITO on Base: 0x548D3B444da39686d1a6F1544781d154e7cD1EF7
    IERC20 public immutable sKaito;

    address public relayer;
    address public guardian;
    uint256 public depositCap;
    uint256 public totalLiabilities;
    uint256 public depositNonce;

    mapping(bytes32 => bool) public released;

    event RelayerUpdated(address indexed oldRelayer, address indexed newRelayer);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event DepositCapUpdated(uint256 cap);
    event Deposited(address indexed user, uint256 amount, bytes32 indexed depositId, uint256 nonce);
    event Released(address indexed user, uint256 amount, bytes32 indexed redeemId);
    event SurplusSkimmed(address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error CapExceeded();
    error AlreadyReleased();
    error InsufficientLiability();
    error NotRelayer();
    error NotGuardian();
    error NoSurplus();

    modifier onlyRelayer() {
        if (msg.sender != relayer) revert NotRelayer();
        _;
    }

    constructor(address _sKaito, address _relayer, address _guardian, uint256 _depositCap)
        Ownable(msg.sender)
    {
        if (_sKaito == address(0) || _relayer == address(0) || _guardian == address(0)) {
            revert ZeroAddress();
        }
        sKaito = IERC20(_sKaito);
        relayer = _relayer;
        guardian = _guardian;
        depositCap = _depositCap;
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

    function setDepositCap(uint256 cap) external onlyOwner {
        depositCap = cap;
        emit DepositCapUpdated(cap);
    }

    function pause() external {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardian();
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (totalLiabilities + amount > depositCap) revert CapExceeded();

        sKaito.safeTransferFrom(msg.sender, address(this), amount);
        totalLiabilities += amount;

        uint256 nonce = ++depositNonce;
        bytes32 depositId = keccak256(abi.encode(block.chainid, address(this), msg.sender, amount, nonce));
        emit Deposited(msg.sender, amount, depositId, nonce);
    }

    function release(address to, uint256 amount, bytes32 redeemId) external nonReentrant onlyRelayer {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (released[redeemId]) revert AlreadyReleased();
        if (amount > totalLiabilities) revert InsufficientLiability();

        released[redeemId] = true;
        totalLiabilities -= amount;
        sKaito.safeTransfer(to, amount);
        emit Released(to, amount, redeemId);
    }

    function surplus() public view returns (uint256) {
        uint256 bal = sKaito.balanceOf(address(this));
        return bal > totalLiabilities ? bal - totalLiabilities : 0;
    }

    function skimSurplus(address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        uint256 extra = surplus();
        if (extra == 0) revert NoSurplus();
        sKaito.safeTransfer(to, extra);
        emit SurplusSkimmed(to, extra);
    }
}
