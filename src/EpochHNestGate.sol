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
}

/// @title EpochHNestGate
/// @notice Optional mint-delay router in front of NestVault. Circulating hNEST
///         stays a normal ERC-20. Live vault 0x4f6615… has no depositGate and
///         cannot be patched; this contract is how new HyperLeaf deposits wait
///         for Nest epoch settlement. Direct vault deposits remain possible on
///         the live immutable vault.
///
///         4d = HEV dettach (not this contract)
///         7d = Nest epoch (Thursday UTC)
///         8d = min circulation delay
///         claimableAt = max(deposit + 8d, epochEnd + 30m)
contract EpochHNestGate is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_FEE_BPS = 500;
    uint256 public constant NEST_EPOCH_LENGTH = 7 days;
    uint256 public constant HNEST_MINT_DELAY = 8 days;
    /// @dev HYPE cannot be sealed until the Nest epoch has been closed plus this
    ///      buffer. Blocks allocateHype(epoch, 0) on day 0 from killing the week.
    uint256 public constant HYPE_FINALIZE_DELAY = 1 days;

    IERC20 public immutable nestToken;
    IERC20 public immutable hypeToken;
    IERC20 public immutable hNest;
    INestVaultDeposit public immutable vault;

    address public keeper;
    address public guardian;
    address public feeRecipient;
    uint256 public feeBps = 100;
    uint256 public currentEpochId;

    struct Epoch {
        uint256 start;
        uint256 end;
        uint256 claimableAt;
        uint256 totalNest;
        uint256 totalHNest;
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

    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event EpochOpened(uint256 indexed epochId, uint256 start, uint256 end, uint256 claimableAt);
    event EpochClosed(uint256 indexed epochId);
    event Deposited(uint256 indexed epochId, address indexed user, uint256 nestAmount, uint256 hNestMinted, uint256 claimableAt);
    event HypeAllocated(uint256 indexed epochId, uint256 gross, uint256 fee, uint256 net);
    event HypeFinalized(uint256 indexed epochId, uint256 net);
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

    /// @notice Close the current Nest week and open the next. Late keeper
    ///         skips empty weeks so the live epoch is always the Thursday
    ///         week containing now. allocateHype does not replace this.
    function rollEpoch() external onlyKeeper {
        Epoch storage cur = epochs[currentEpochId];
        if (block.timestamp < cur.end) revert EpochStillOpen();
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

    function deposit(uint256 nestAmount) external nonReentrant whenNotPaused {
        if (nestAmount == 0) revert ZeroAmount();
        Epoch storage ep = epochs[currentEpochId];
        if (ep.closed || block.timestamp >= ep.end) revert EpochNotOpen();

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

        emit Deposited(currentEpochId, msg.sender, nestAmount, minted, userClaimableAt[currentEpochId][msg.sender]);
    }

    /// @notice Add this week's HYPE. Can be called more than once until finalize.
    ///         amount=0 is rejected so a keeper cannot seal the week empty on day 0.
    function allocateHype(uint256 epochId, uint256 amount) external onlyKeeper nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Epoch storage ep = epochs[epochId];
        if (block.timestamp < ep.end) revert EpochStillOpen();
        if (ep.hypeFinal) revert HypeAlreadyFinal();
        if (ep.start == 0) revert EpochNotOpen();

        hypeToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 fee = (amount * feeBps) / BASIS_POINTS;
        uint256 net = amount - fee;
        if (fee > 0) hypeToken.safeTransfer(feeRecipient, fee);
        ep.hypeAllocated += net;
        ep.hypeFeeTaken += fee;
        emit HypeAllocated(epochId, amount, fee, net);
    }

    /// @notice Seal the week's HYPE (including a genuine 0). Only after
    ///         epochEnd + 1 day, so harvest has time to land.
    function finalizeHype(uint256 epochId) external onlyKeeper {
        Epoch storage ep = epochs[epochId];
        if (ep.start == 0) revert EpochNotOpen();
        if (ep.hypeFinal) revert HypeAlreadyFinal();
        uint256 earliest = ep.end + HYPE_FINALIZE_DELAY;
        if (block.timestamp < earliest) revert FinalizeTooEarly(earliest);
        ep.hypeFinal = true;
        emit HypeFinalized(epochId, ep.hypeAllocated);
    }

    function claim(uint256 epochId) external nonReentrant {
        Epoch storage ep = epochs[epochId];
        if (!ep.hypeFinal) revert HypeNotFinal();

        uint256 owedH = hNestOwed[epochId][msg.sender];
        if (owedH == 0) revert NothingOwed();
        if (hNestTaken[epochId][msg.sender]) revert AlreadyTaken();

        uint256 claimableAt_ = userClaimableAt[epochId][msg.sender];
        if (block.timestamp < claimableAt_) revert MintDelayActive(claimableAt_);

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
        claimable = ep.hypeFinal && !hNestTaken[epochId][user] && hNestOwed[epochId][user] > 0
            && block.timestamp >= userClaimableAt[epochId][user];
    }

    function _openEpoch(uint256 epochId, uint256 start) internal {
        uint256 end = HNestCirculation.epochEnd(start);
        if (end <= start) end = start + NEST_EPOCH_LENGTH;
        uint256 claimableAt_ = HNestCirculation.claimableAt(start);
        epochs[epochId].start = start;
        epochs[epochId].end = end;
        epochs[epochId].claimableAt = claimableAt_;
        emit EpochOpened(epochId, start, end, claimableAt_);
    }
}
