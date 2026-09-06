// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

interface INestVaultDeposit {
    function deposit(uint256 nestAmount) external;
    function hNest() external view returns (address);
    function nestToken() external view returns (address);
}

/// @title EpochHNestGate
/// @notice Option-2 gate in front of an already-deployed NestVault.
///         New NEST is deposited into the vault by THIS contract, so hNEST is
///         minted to the gate — not to the user — until the epoch is finalized
///         and that week's HYPE (if any) has been allocated.
/// @dev HYPE does NOT auto-claim from Nest. Keeper/owner must send realized
///      HYPE into the gate and call `allocateHype`. Do not re-enable
///      NestVault.recordCompound. Align `epochLength` with Nest weeks off-chain.
contract EpochHNestGate is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable nestToken;
    IERC20 public immutable hypeToken;
    IERC20 public immutable hNest;
    INestVaultDeposit public immutable vault;

    address public keeper;
    uint256 public epochLength = 7 days;
    uint256 public currentEpochId;
    uint256 public currentEpochStart;

    struct Epoch {
        uint256 start;
        uint256 end;
        uint256 totalNest;
        uint256 totalHNest;
        uint256 hypeAllocated;
        bool closed;
        bool hypeFinal;
    }

    mapping(uint256 => Epoch) public epochs;
    mapping(uint256 => mapping(address => uint256)) public nestIn;
    mapping(uint256 => mapping(address => uint256)) public hNestOwed;
    mapping(uint256 => mapping(address => bool)) public hNestTaken;
    mapping(uint256 => mapping(address => bool)) public hypeTaken;

    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);
    event EpochOpened(uint256 indexed epochId, uint256 start, uint256 end);
    event EpochClosed(uint256 indexed epochId);
    event Deposited(uint256 indexed epochId, address indexed user, uint256 nestAmount, uint256 hNestMinted);
    event HypeAllocated(uint256 indexed epochId, uint256 amount);
    event Claimed(uint256 indexed epochId, address indexed user, uint256 hNestAmount, uint256 hypeAmount);

    error ZeroAmount();
    error ZeroAddress();
    error NotKeeper();
    error EpochNotClosed();
    error EpochStillOpen();
    error AlreadyTaken();
    error NothingOwed();
    error HypeAlreadyFinal();
    error TooEarly();

    modifier onlyKeeper() {
        if (msg.sender != keeper && msg.sender != owner()) revert NotKeeper();
        _;
    }

    constructor(address _vault, address _hypeToken, address _keeper) Ownable(msg.sender) {
        if (_vault == address(0) || _hypeToken == address(0) || _keeper == address(0)) revert ZeroAddress();
        vault = INestVaultDeposit(_vault);
        nestToken = IERC20(vault.nestToken());
        hNest = IERC20(vault.hNest());
        hypeToken = IERC20(_hypeToken);
        keeper = _keeper;
        nestToken.forceApprove(_vault, type(uint256).max);
        currentEpochStart = block.timestamp;
        epochs[0].start = block.timestamp;
        epochs[0].end = block.timestamp + epochLength;
        emit EpochOpened(0, epochs[0].start, epochs[0].end);
    }

    function setKeeper(address _keeper) external onlyOwner {
        if (_keeper == address(0)) revert ZeroAddress();
        emit KeeperUpdated(keeper, _keeper);
        keeper = _keeper;
    }

    function setEpochLength(uint256 _len) external onlyOwner {
        if (_len < 1 days || _len > 30 days) revert TooEarly();
        epochLength = _len;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Roll to a new epoch. Old epoch stops accepting deposits.
    function rollEpoch() external onlyKeeper {
        Epoch storage cur = epochs[currentEpochId];
        if (block.timestamp < cur.end && cur.totalNest > 0) revert EpochStillOpen();
        cur.closed = true;
        emit EpochClosed(currentEpochId);

        currentEpochId += 1;
        currentEpochStart = block.timestamp;
        epochs[currentEpochId].start = block.timestamp;
        epochs[currentEpochId].end = block.timestamp + epochLength;
        emit EpochOpened(currentEpochId, epochs[currentEpochId].start, epochs[currentEpochId].end);
    }

    /// @notice Deposit NEST for the CURRENT epoch. hNEST stays in this contract.
    function deposit(uint256 nestAmount) external nonReentrant whenNotPaused {
        if (nestAmount == 0) revert ZeroAmount();
        Epoch storage ep = epochs[currentEpochId];
        if (ep.closed) revert EpochNotClosed();
        if (block.timestamp >= ep.end) revert EpochStillOpen();

        nestToken.safeTransferFrom(msg.sender, address(this), nestAmount);

        uint256 hBefore = hNest.balanceOf(address(this));
        vault.deposit(nestAmount);
        uint256 minted = hNest.balanceOf(address(this)) - hBefore;
        if (minted == 0) revert ZeroAmount();

        nestIn[currentEpochId][msg.sender] += nestAmount;
        hNestOwed[currentEpochId][msg.sender] += minted;
        ep.totalNest += nestAmount;
        ep.totalHNest += minted;

        emit Deposited(currentEpochId, msg.sender, nestAmount, minted);
    }

    /// @notice After Nest week settles, pull HYPE into this contract first, then allocate.
    ///         Splits by nestIn weight for that epoch only (new locks that week).
    function allocateHype(uint256 epochId, uint256 amount) external onlyKeeper nonReentrant {
        Epoch storage ep = epochs[epochId];
        if (!ep.closed && block.timestamp < ep.end) revert EpochStillOpen();
        ep.closed = true;
        if (ep.hypeFinal) revert HypeAlreadyFinal();
        if (amount == 0) {
            ep.hypeFinal = true;
            emit HypeAllocated(epochId, 0);
            return;
        }
        hypeToken.safeTransferFrom(msg.sender, address(this), amount);
        ep.hypeAllocated += amount;
        ep.hypeFinal = true;
        emit HypeAllocated(epochId, amount);
    }

    /// @notice After hypeFinal, user receives transferable hNEST + pro-rata HYPE for THAT epoch.
    function claim(uint256 epochId) external nonReentrant {
        Epoch storage ep = epochs[epochId];
        if (!ep.hypeFinal) revert EpochNotClosed();

        uint256 owedH = hNestOwed[epochId][msg.sender];
        if (owedH == 0) revert NothingOwed();
        if (hNestTaken[epochId][msg.sender]) revert AlreadyTaken();

        hNestTaken[epochId][msg.sender] = true;

        uint256 hypeAmt;
        if (ep.hypeAllocated > 0 && ep.totalNest > 0) {
            hypeAmt = (nestIn[epochId][msg.sender] * ep.hypeAllocated) / ep.totalNest;
        }
        if (hypeAmt > 0) {
            hypeTaken[epochId][msg.sender] = true;
            hypeToken.safeTransfer(msg.sender, hypeAmt);
        }
        hNest.safeTransfer(msg.sender, owedH);

        emit Claimed(epochId, msg.sender, owedH, hypeAmt);
    }

    function pending(uint256 epochId, address user)
        external
        view
        returns (uint256 nestDeposited, uint256 hNestAmount, uint256 hypeAmount, bool claimable)
    {
        Epoch storage ep = epochs[epochId];
        nestDeposited = nestIn[epochId][user];
        hNestAmount = hNestTaken[epochId][user] ? 0 : hNestOwed[epochId][user];
        if (ep.hypeFinal && ep.totalNest > 0 && !hypeTaken[epochId][user]) {
            hypeAmount = (nestIn[epochId][user] * ep.hypeAllocated) / ep.totalNest;
        }
        claimable = ep.hypeFinal && !hNestTaken[epochId][user] && hNestOwed[epochId][user] > 0;
    }
}
