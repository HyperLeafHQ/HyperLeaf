// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {HNestCirculation} from "./HNestCirculation.sol";

interface INestVaultDeposit {
    function deposit(uint256 nestAmount) external;
    function hNest() external view returns (address);
    function nestToken() external view returns (address);
    function pendingResidualHype(address user) external view returns (uint256);
    function claimResidualHype() external;
}

/// @title EpochHNestGate
/// @notice Mint-delay router in front of NestVault. Circulating hNEST stays ERC-20.
///
///         Live vault 0x4f6615… has no depositGate and cannot be patched.
///         Do not advertise weekly HYPE isolation until this Gate is the
///         actual deposit path (frontend +, for a future vault, one-shot gate).
///
///         4d  = HEV dettach (not this contract)
///         7d  = Nest epoch (Thursday UTC)
///         8d  = min circulation delay
///         claimableAt = max(deposit + 8d, epochEnd + 30m)
///
///         Epoch HYPE (allocateHype) is for *this week's new deposits*.
///         Vault residual HYPE earned while Gate holds hNEST is a separate index.
contract EpochHNestGate is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_FEE_BPS = 500;
    uint256 public constant NEST_EPOCH_LENGTH = 7 days;
    uint256 public constant HNEST_MINT_DELAY = 8 days;
    uint256 public constant HYPE_FINALIZE_DELAY = 1 days;
    uint256 public constant RESIDUAL_INDEX_SCALE = 1e18;

    IERC20 public immutable nestToken;
    IERC20 public immutable hypeToken;
    IERC20 public immutable hNest;
    INestVaultDeposit public immutable vault;

    address public keeper;
    address public guardian;
    address public feeRecipient;
    uint256 public feeBps = 100;
    uint256 public currentEpochId;

    uint256 public vaultResidualIndex;
    uint256 public vaultResidualRemainder;

    struct Epoch {
        uint256 start;
        uint256 end;
        uint256 claimableAt;
        uint256 totalNest;
        uint256 totalHNest;
        uint256 feeBpsSnapshot;
        address feeRecipientSnapshot;
        uint256 hypeAllocated;
        uint256 hypeFeeTaken;
        bool closed;
        bool hypeFinal;
    }

    mapping(uint256 => Epoch) public epochs;
    mapping(uint256 => mapping(address => uint256)) public nestIn;
    mapping(uint256 => mapping(address => uint256)) public hNestOwed;
    mapping(uint256 => mapping(address => uint256)) public userClaimableAt;
    mapping(uint256 => mapping(address => bool)) public hNestTaken;
    mapping(uint256 => mapping(address => bool)) public hypeTaken;
    mapping(uint256 => mapping(address => uint256)) public vaultResidualIndexPaid;
    mapping(uint256 => mapping(address => uint256)) public vaultResidualOwed;

    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event EpochOpened(uint256 indexed epochId, uint256 start, uint256 end, uint256 claimableAt);
    event EpochClosed(uint256 indexed epochId);
    event Deposited(uint256 indexed epochId, address indexed user, uint256 nestAmount, uint256 hNestMinted, uint256 claimableAt);
    event HypeAllocated(uint256 indexed epochId, uint256 gross, uint256 fee, uint256 net);
    event HypeFinalized(uint256 indexed epochId, uint256 net);
    event VaultResidualHypeSynced(uint256 amount, uint256 index, uint256 remainder);
    event Claimed(uint256 indexed epochId, address indexed user, uint256 hNestAmount, uint256 hypeAmount);

    error ZeroAmount();
    error ZeroAddress();
    error NotKeeper();
    error NotGuardian();
    error EpochNotOpen();
    error EpochStillOpen();
    error MintDelayActive(uint256 claimableAt);
    error AlreadyTaken();
    error NothingOwed();
    error HypeAlreadyFinal();
    error HypeNotFinal();
    error FeeTooHigh();
    error FinalizeTooEarly(uint256 earliest);

    modifier onlyKeeper() {
        if (msg.sender != keeper && msg.sender != owner()) revert NotKeeper();
        _;
    }

    constructor(address _vault, address _hypeToken, address _keeper, address _guardian, address _feeRecipient)
        Ownable(msg.sender)
    {
        if (
            _vault == address(0) || _hypeToken == address(0) || _keeper == address(0) || _feeRecipient == address(0)
        ) revert ZeroAddress();
        vault = INestVaultDeposit(_vault);
        nestToken = IERC20(vault.nestToken());
        hNest = IERC20(vault.hNest());
        hypeToken = IERC20(_hypeToken);
        keeper = _keeper;
        guardian = _guardian;
        feeRecipient = _feeRecipient;
        nestToken.forceApprove(_vault, type(uint256).max);
        _openEpoch(0, block.timestamp);
    }

    function setKeeper(address _keeper) external onlyOwner {
        if (_keeper == address(0)) revert ZeroAddress();
        emit KeeperUpdated(keeper, _keeper);
        keeper = _keeper;
    }

    function setGuardian(address _guardian) external onlyOwner {
        emit GuardianUpdated(guardian, _guardian);
        guardian = _guardian;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function setFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        emit FeeUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    function pause() external {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardian();
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Permissionless. Keeper absence must not freeze deposits.
    function rollEpoch() external {
        Epoch storage cur = epochs[currentEpochId];
        if (block.timestamp < cur.end) revert EpochStillOpen();
        _rollEpoch();
    }

    function deposit(uint256 nestAmount) external nonReentrant whenNotPaused {
        if (nestAmount == 0) revert ZeroAmount();
        Epoch storage ep = epochs[currentEpochId];
        if (block.timestamp >= ep.end) {
            _rollEpoch();
            ep = epochs[currentEpochId];
        }
        if (ep.closed) revert EpochNotOpen();

        _checkpointVaultResidual(currentEpochId, msg.sender, hNestOwed[currentEpochId][msg.sender]);

        nestToken.safeTransferFrom(msg.sender, address(this), nestAmount);

        uint256 hBefore = hNest.balanceOf(address(this));
        vault.deposit(nestAmount);
        uint256 minted = hNest.balanceOf(address(this)) - hBefore;
        if (minted == 0) revert ZeroAmount();

        nestIn[currentEpochId][msg.sender] += nestAmount;
        hNestOwed[currentEpochId][msg.sender] += minted;
        ep.totalNest += nestAmount;
        ep.totalHNest += minted;

        uint256 unlockAt = HNestCirculation.claimableAt(block.timestamp);
        if (unlockAt < ep.claimableAt) unlockAt = ep.claimableAt;
        if (unlockAt > userClaimableAt[currentEpochId][msg.sender]) {
            userClaimableAt[currentEpochId][msg.sender] = unlockAt;
        }
        vaultResidualIndexPaid[currentEpochId][msg.sender] = vaultResidualIndex;

        emit Deposited(currentEpochId, msg.sender, nestAmount, minted, userClaimableAt[currentEpochId][msg.sender]);
    }

    /// @notice Keeper adds this week's new-deposit HYPE. amount=0 rejected.
    ///         Uses the fee/recipient snapshotted when the epoch opened.
    function allocateHype(uint256 epochId, uint256 amount) external onlyKeeper nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Epoch storage ep = epochs[epochId];
        if (block.timestamp < ep.end) revert EpochStillOpen();
        if (ep.hypeFinal) revert HypeAlreadyFinal();
        if (ep.start == 0) revert EpochNotOpen();

        hypeToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 fee = (amount * ep.feeBpsSnapshot) / BASIS_POINTS;
        uint256 net = amount - fee;
        if (fee > 0) hypeToken.safeTransfer(ep.feeRecipientSnapshot, fee);
        ep.hypeAllocated += net;
        ep.hypeFeeTaken += fee;
        emit HypeAllocated(epochId, amount, fee, net);
    }

    /// @notice Permissionless after epochEnd + 1 day. Seals whatever was allocated
    ///         (including 0) so users are not stuck if the keeper disappears.
    function finalizeHype(uint256 epochId) external {
        Epoch storage ep = epochs[epochId];
        if (ep.start == 0) revert EpochNotOpen();
        if (ep.hypeFinal) revert HypeAlreadyFinal();
        uint256 earliest = ep.end + HYPE_FINALIZE_DELAY;
        if (block.timestamp < earliest) revert FinalizeTooEarly(earliest);
        ep.hypeFinal = true;
        emit HypeFinalized(epochId, ep.hypeAllocated);
    }

    function syncVaultResidualHype() external nonReentrant returns (uint256 synced) {
        synced = _syncVaultResidualHype();
    }

    function claim(uint256 epochId) external nonReentrant {
        Epoch storage ep = epochs[epochId];
        if (!ep.hypeFinal) revert HypeNotFinal();

        uint256 owedH = hNestOwed[epochId][msg.sender];
        if (owedH == 0) revert NothingOwed();
        if (hNestTaken[epochId][msg.sender]) revert AlreadyTaken();

        uint256 claimableAt_ = userClaimableAt[epochId][msg.sender];
        if (block.timestamp < claimableAt_) revert MintDelayActive(claimableAt_);

        _checkpointVaultResidual(epochId, msg.sender, owedH);
        uint256 residualAmt = vaultResidualOwed[epochId][msg.sender];
        vaultResidualOwed[epochId][msg.sender] = 0;
        hNestTaken[epochId][msg.sender] = true;

        uint256 hypeAmt;
        if (ep.hypeAllocated > 0 && ep.totalNest > 0) {
            hypeAmt = (nestIn[epochId][msg.sender] * ep.hypeAllocated) / ep.totalNest;
        }
        if (hypeAmt > 0) {
            hypeTaken[epochId][msg.sender] = true;
            hypeToken.safeTransfer(msg.sender, hypeAmt);
        }
        if (residualAmt > 0) {
            hypeToken.safeTransfer(msg.sender, residualAmt);
        }
        hNest.safeTransfer(msg.sender, owedH);

        emit Claimed(epochId, msg.sender, owedH, hypeAmt + residualAmt);
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
        claimable = ep.hypeFinal && !hNestTaken[epochId][user] && hNestOwed[epochId][user] > 0
            && block.timestamp >= userClaimableAt[epochId][user];
    }

    function pendingVaultResidual(uint256 epochId, address user) external view returns (uint256 amount) {
        uint256 owedH = hNestOwed[epochId][user];
        uint256 checkpoint = vaultResidualIndexPaid[epochId][user];
        uint256 accrued = owedH * (vaultResidualIndex - checkpoint) / RESIDUAL_INDEX_SCALE;
        amount = vaultResidualOwed[epochId][user] + accrued;
    }

    function _rollEpoch() internal {
        Epoch storage cur = epochs[currentEpochId];
        _syncVaultResidualHype();
        if (!cur.closed) {
            cur.closed = true;
            emit EpochClosed(currentEpochId);
        }
        uint256 nextStart = cur.end;
        while (nextStart + NEST_EPOCH_LENGTH <= block.timestamp) {
            nextStart += NEST_EPOCH_LENGTH;
        }
        currentEpochId += 1;
        _openEpoch(currentEpochId, nextStart);
    }

    function _openEpoch(uint256 epochId, uint256 start) internal {
        uint256 end = HNestCirculation.epochEnd(start);
        if (end <= start) end = start + NEST_EPOCH_LENGTH;
        uint256 claimableAt_ = HNestCirculation.claimableAt(start);
        Epoch storage ep = epochs[epochId];
        ep.start = start;
        ep.end = end;
        ep.claimableAt = claimableAt_;
        ep.feeBpsSnapshot = feeBps;
        ep.feeRecipientSnapshot = feeRecipient;
        emit EpochOpened(epochId, start, end, claimableAt_);
    }

    function _syncVaultResidualHype() internal returns (uint256 synced) {
        synced = vault.pendingResidualHype(address(this));
        if (synced > 0) vault.claimResidualHype();

        uint256 gateBalance = hNest.balanceOf(address(this));
        uint256 distributable = synced + vaultResidualRemainder;
        if (distributable == 0) return synced;

        if (gateBalance == 0) {
            vaultResidualRemainder = distributable;
            emit VaultResidualHypeSynced(synced, vaultResidualIndex, vaultResidualRemainder);
            return synced;
        }

        uint256 increment = distributable * RESIDUAL_INDEX_SCALE / gateBalance;
        uint256 accounted = increment * gateBalance / RESIDUAL_INDEX_SCALE;
        vaultResidualIndex += increment;
        vaultResidualRemainder = distributable - accounted;
        emit VaultResidualHypeSynced(synced, vaultResidualIndex, vaultResidualRemainder);
    }

    function _checkpointVaultResidual(uint256 epochId, address user, uint256 owedH) internal {
        _syncVaultResidualHype();
        uint256 checkpoint = vaultResidualIndexPaid[epochId][user];
        if (owedH > 0 && vaultResidualIndex > checkpoint) {
            vaultResidualOwed[epochId][user] += owedH * (vaultResidualIndex - checkpoint) / RESIDUAL_INDEX_SCALE;
        }
        vaultResidualIndexPaid[epochId][user] = vaultResidualIndex;
    }
}
