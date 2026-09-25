// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {HNestCirculation} from "./HNestCirculation.sol";

interface INestVaultDepositV2 {
    function deposit(uint256 nestAmount) external;
    function hNest() external view returns (address);
    function nestToken() external view returns (address);
    function pendingResidualHype(address user) external view returns (uint256);
    function claimResidualHype() external;
}

/// @title EpochHNestGateV2
/// @notice Replacement Gate. Live V1 `0x900b…` is not upgradeable.
///
///         Product:
///         - Gate delay stays 8 days (HNestCirculation). A deposit always
///           spans at least two Nest weeks. That is the normal path.
///         - New-deposit HYPE is only the deposit epoch's `hypeAllocated`.
///           Claiming in week 2/3/4 never taps a later epoch's new-deposit pot.
///         - Later weeks while still locked: Nest growth on *this* position
///           only. New deposits of the current epoch are not in the growth
///           denominator.
///
///         Routing:
///         - `rollEpoch` pulls vault residual into the *closing* epoch
///           allocate pot (that week's new deposits).
///         - Mid-epoch `syncGrowthHype` pulls vault residual into the carry
///           growth index (`carryHNest` = unclaimed hNEST from older epochs).
contract EpochHNestGateV2 is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_FEE_BPS = 500;
    uint256 public constant NEST_EPOCH_LENGTH = 7 days;
    uint256 public constant HNEST_MINT_DELAY = 8 days;
    uint256 public constant HYPE_FINALIZE_DELAY = 1 days;
    uint256 public constant GROWTH_INDEX_SCALE = 1e18;
    uint256 public constant MAX_TRANCHES_PER_EPOCH = 32;

    IERC20 public immutable nestToken;
    IERC20 public immutable hypeToken;
    IERC20 public immutable hNest;
    INestVaultDepositV2 public immutable vault;

    address public keeper;
    address public guardian;
    address public feeRecipient;
    uint256 public feeBps = 100;
    uint256 public currentEpochId;

    /// @notice Unclaimed hNEST deposited in epochs < currentEpochId.
    uint256 public carryHNest;
    uint256 public growthIndex;
    uint256 public growthRemainder;

    struct Epoch {
        uint256 start;
        uint256 end;
        uint256 claimableAt;
        uint256 totalNest;
        uint256 totalHNest;
        uint256 unclaimedHNest;
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
    mapping(uint256 => mapping(address => uint256)) public growthIndexPaid;
    mapping(uint256 => mapping(address => uint256)) public growthOwed;

    struct DepositTranche {
        uint256 nestAmount;
        uint256 hNestAmount;
        uint256 claimableAt;
        bool claimed;
    }

    mapping(uint256 => mapping(address => DepositTranche[])) internal _tranches;

    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event EpochOpened(uint256 indexed epochId, uint256 start, uint256 end, uint256 claimableAt);
    event EpochClosed(uint256 indexed epochId);
    event Deposited(uint256 indexed epochId, address indexed user, uint256 nestAmount, uint256 hNestMinted, uint256 claimableAt);
    event HypeAllocated(uint256 indexed epochId, uint256 gross, uint256 fee, uint256 net);
    event HypeFinalized(uint256 indexed epochId, uint256 net);
    event ClosingResidualAllocated(uint256 indexed epochId, uint256 amount);
    event GrowthHypeSynced(uint256 amount, uint256 index, uint256 remainder);
    event Claimed(uint256 indexed epochId, address indexed user, uint256 hNestAmount, uint256 newDepositHype, uint256 growthHype);

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
    error TooManyTranches();
    error UnknownTranche();

    modifier onlyKeeper() {
        if (msg.sender != keeper && msg.sender != owner()) revert NotKeeper();
        _;
    }

    constructor(address _vault, address _hypeToken, address _keeper, address _guardian, address _feeRecipient)
        Ownable(msg.sender)
    {
        if (_vault == address(0) || _hypeToken == address(0) || _keeper == address(0) || _feeRecipient == address(0)) {
            revert ZeroAddress();
        }
        vault = INestVaultDepositV2(_vault);
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

        _syncGrowthHype();
        _checkpointGrowth(currentEpochId, msg.sender);

        nestToken.safeTransferFrom(msg.sender, address(this), nestAmount);

        uint256 hBefore = hNest.balanceOf(address(this));
        vault.deposit(nestAmount);
        uint256 minted = hNest.balanceOf(address(this)) - hBefore;
        if (minted == 0) revert ZeroAmount();

        nestIn[currentEpochId][msg.sender] += nestAmount;
        hNestOwed[currentEpochId][msg.sender] += minted;
        ep.totalNest += nestAmount;
        ep.totalHNest += minted;
        ep.unclaimedHNest += minted;

        uint256 unlockAt = HNestCirculation.claimableAt(block.timestamp);
        if (unlockAt < ep.claimableAt) unlockAt = ep.claimableAt;
        DepositTranche[] storage ts = _tranches[currentEpochId][msg.sender];
        if (ts.length >= MAX_TRANCHES_PER_EPOCH) revert TooManyTranches();
        ts.push(DepositTranche({nestAmount: nestAmount, hNestAmount: minted, claimableAt: unlockAt, claimed: false}));
        growthIndexPaid[currentEpochId][msg.sender] = growthIndex;

        emit Deposited(currentEpochId, msg.sender, nestAmount, minted, unlockAt);
    }

    /// @notice Optional extra new-deposit HYPE from the keeper wallet.
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

    function finalizeHype(uint256 epochId) external {
        Epoch storage ep = epochs[epochId];
        if (ep.start == 0) revert EpochNotOpen();
        if (ep.hypeFinal) revert HypeAlreadyFinal();
        uint256 earliest = ep.end + HYPE_FINALIZE_DELAY;
        if (block.timestamp < earliest) revert FinalizeTooEarly(earliest);
        ep.hypeFinal = true;
        emit HypeFinalized(epochId, ep.hypeAllocated);
    }

    function syncGrowthHype() external nonReentrant returns (uint256 synced) {
        synced = _syncGrowthHype();
    }

    function claim(uint256 epochId) external nonReentrant {
        DepositTranche[] storage ts = _tranches[epochId][msg.sender];
        uint256 n = ts.length;
        uint256 earliest;
        for (uint256 i; i < n; ++i) {
            if (ts[i].claimed) continue;
            if (block.timestamp >= ts[i].claimableAt) {
                _claimTranche(epochId, i);
                return;
            }
            if (earliest == 0 || ts[i].claimableAt < earliest) earliest = ts[i].claimableAt;
        }
        if (earliest != 0) revert MintDelayActive(earliest);
        revert NothingOwed();
    }

    function claimTranche(uint256 epochId, uint256 trancheIndex) external nonReentrant {
        _claimTranche(epochId, trancheIndex);
    }

    function depositTranches(uint256 epochId, address user, uint256 i)
        external
        view
        returns (uint256 nestAmount, uint256 hNestAmount, uint256 claimableAt_, bool claimed)
    {
        DepositTranche storage t = _tranches[epochId][user][i];
        return (t.nestAmount, t.hNestAmount, t.claimableAt, t.claimed);
    }

    function trancheCount(uint256 epochId, address user) external view returns (uint256) {
        return _tranches[epochId][user].length;
    }

    function pending(uint256 epochId, address user)
        external
        view
        returns (uint256 nestDeposited, uint256 hNestAmount, uint256 newDepositHype, uint256 growthHype, bool claimable)
    {
        Epoch storage ep = epochs[epochId];
        nestDeposited = nestIn[epochId][user];
        DepositTranche[] storage ts = _tranches[epochId][user];
        uint256 n = ts.length;
        for (uint256 i; i < n; ++i) {
            if (ts[i].claimed) continue;
            hNestAmount += ts[i].hNestAmount;
            if (ep.hypeFinal && ep.totalNest > 0) {
                newDepositHype += (ts[i].nestAmount * ep.hypeAllocated) / ep.totalNest;
            }
            if (ep.hypeFinal && block.timestamp >= ts[i].claimableAt) claimable = true;
        }
        growthHype = _pendingGrowth(epochId, user);
    }

    function pendingGrowth(uint256 epochId, address user) external view returns (uint256) {
        return _pendingGrowth(epochId, user);
    }

    function _claimTranche(uint256 epochId, uint256 trancheIndex) internal {
        Epoch storage ep = epochs[epochId];
        if (!ep.hypeFinal) revert HypeNotFinal();
        DepositTranche[] storage ts = _tranches[epochId][msg.sender];
        if (trancheIndex >= ts.length) revert UnknownTranche();
        DepositTranche storage t = ts[trancheIndex];
        if (t.claimed) revert AlreadyTaken();
        if (block.timestamp < t.claimableAt) revert MintDelayActive(t.claimableAt);

        _syncGrowthHype();
        uint256 remainingH = hNestOwed[epochId][msg.sender];
        _checkpointGrowth(epochId, msg.sender);

        uint256 growthPay;
        if (remainingH > 0 && growthOwed[epochId][msg.sender] > 0) {
            growthPay = (growthOwed[epochId][msg.sender] * t.hNestAmount) / remainingH;
            growthOwed[epochId][msg.sender] -= growthPay;
        }

        t.claimed = true;
        hNestOwed[epochId][msg.sender] = remainingH - t.hNestAmount;
        ep.unclaimedHNest -= t.hNestAmount;
        if (epochId < currentEpochId) {
            carryHNest -= t.hNestAmount;
        }

        uint256 newDepositPay;
        if (ep.hypeAllocated > 0 && ep.totalNest > 0) {
            newDepositPay = (t.nestAmount * ep.hypeAllocated) / ep.totalNest;
        }
        if (newDepositPay > 0) hypeToken.safeTransfer(msg.sender, newDepositPay);
        if (growthPay > 0) hypeToken.safeTransfer(msg.sender, growthPay);
        hNest.safeTransfer(msg.sender, t.hNestAmount);
        emit Claimed(epochId, msg.sender, t.hNestAmount, newDepositPay, growthPay);
    }

    function _rollEpoch() internal {
        Epoch storage cur = epochs[currentEpochId];
        _allocateClosingResidual(currentEpochId);
        if (!cur.closed) {
            cur.closed = true;
            carryHNest += cur.unclaimedHNest;
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

    function _pullVaultResidual() internal returns (uint256 pulled) {
        pulled = vault.pendingResidualHype(address(this));
        if (pulled > 0) vault.claimResidualHype();
    }

    function _allocateClosingResidual(uint256 epochId) internal {
        uint256 pulled = _pullVaultResidual();
        if (pulled == 0) return;
        epochs[epochId].hypeAllocated += pulled;
        emit ClosingResidualAllocated(epochId, pulled);
    }

    function _syncGrowthHype() internal returns (uint256 synced) {
        synced = _pullVaultResidual();
        uint256 distributable = synced + growthRemainder;
        if (distributable == 0) return synced;
        if (carryHNest == 0) {
            growthRemainder = distributable;
            emit GrowthHypeSynced(synced, growthIndex, growthRemainder);
            return synced;
        }
        uint256 increment = distributable * GROWTH_INDEX_SCALE / carryHNest;
        uint256 accounted = increment * carryHNest / GROWTH_INDEX_SCALE;
        growthIndex += increment;
        growthRemainder = distributable - accounted;
        emit GrowthHypeSynced(synced, growthIndex, growthRemainder);
    }

    function _checkpointGrowth(uint256 epochId, address user) internal {
        if (epochId >= currentEpochId) {
            growthIndexPaid[epochId][user] = growthIndex;
            return;
        }
        uint256 owedH = hNestOwed[epochId][user];
        uint256 paid = growthIndexPaid[epochId][user];
        if (owedH > 0 && growthIndex > paid) {
            growthOwed[epochId][user] += owedH * (growthIndex - paid) / GROWTH_INDEX_SCALE;
        }
        growthIndexPaid[epochId][user] = growthIndex;
    }

    function _pendingGrowth(uint256 epochId, address user) internal view returns (uint256 amount) {
        amount = growthOwed[epochId][user];
        if (epochId >= currentEpochId) return amount;
        uint256 owedH = hNestOwed[epochId][user];
        uint256 paid = growthIndexPaid[epochId][user];
        if (owedH > 0 && growthIndex > paid) {
            amount += owedH * (growthIndex - paid) / GROWTH_INDEX_SCALE;
        }
    }
}
