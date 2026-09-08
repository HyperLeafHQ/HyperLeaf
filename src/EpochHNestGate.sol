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

/**
 * @title EpochHNestGate
 * @notice Mint-delay gate in front of NestVault. Circulating hNEST stays a standard ERC-20.
 *
 * Nest's economic reward epoch is fixed at 7 days. The gate deliberately adds one extra
 * settlement day and also enforces an 8-day minimum delay from the user's latest deposit.
 * This separates the Nest accounting epoch from the user-facing mint-release delay.
 *
 * The 4-day HEV detachment lock is a different mechanism and is NOT the hNEST mint delay.
 */
contract EpochHNestGate is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_FEE_BPS = 500;

    /// @notice Nest's canonical reward/accounting period.
    uint256 public constant NEST_EPOCH_LENGTH = 7 days;
    /// @notice Minimum user-facing time before an epoch deposit can mint circulating hNEST.
    uint256 public constant HNEST_MINT_DELAY = 8 days;
    /// @notice Extra settlement buffer after the 7-day Nest epoch closes.
    uint256 public constant SETTLEMENT_BUFFER = 1 days;

    IERC20 public immutable nestToken;
    IERC20 public immutable hypeToken;
    IERC20 public immutable hNest;
    INestVaultDeposit public immutable vault;

    address public keeper;
    address public feeRecipient;
    uint256 public feeBps = 100; // 1%
    uint256 public currentEpochId;
    uint256 public currentEpochStart;

    struct Epoch {
        uint256 start;
        uint256 end;
        uint256 claimableAt;
        uint256 totalNest;
        uint256 totalHNest;
        uint256 hypeAllocated; // net of protocol fee
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
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event EpochOpened(uint256 indexed epochId, uint256 start, uint256 end, uint256 claimableAt);
    event EpochClosed(uint256 indexed epochId);
    event Deposited(uint256 indexed epochId, address indexed user, uint256 nestAmount, uint256 hNestMinted, uint256 claimableAt);
    event HypeAllocated(uint256 indexed epochId, uint256 gross, uint256 fee, uint256 net);
    event Claimed(uint256 indexed epochId, address indexed user, uint256 hNestAmount, uint256 hypeAmount);

    error ZeroAmount();
    error ZeroAddress();
    error NotKeeper();
    error EpochNotOpen();
    error EpochStillOpen();
    error MintDelayActive(uint256 claimableAt);
    error AlreadyTaken();
    error NothingOwed();
    error HypeAlreadyFinal();
    error FeeTooHigh();

    modifier onlyKeeper() {
        if (msg.sender != keeper && msg.sender != owner()) revert NotKeeper();
        _;
    }

    constructor(address _vault, address _hypeToken, address _keeper, address _feeRecipient) Ownable(msg.sender) {
        if (
            _vault == address(0) || _hypeToken == address(0) || _keeper == address(0) || _feeRecipient == address(0)
        ) revert ZeroAddress();
        vault = INestVaultDeposit(_vault);
        nestToken = IERC20(vault.nestToken());
        hNest = IERC20(vault.hNest());
        hypeToken = IERC20(_hypeToken);
        keeper = _keeper;
        feeRecipient = _feeRecipient;
        nestToken.forceApprove(_vault, type(uint256).max);
        currentEpochStart = block.timestamp;
        _openEpoch(0, block.timestamp);
    }

    function setKeeper(address _keeper) external onlyOwner {
        if (_keeper == address(0)) revert ZeroAddress();
        emit KeeperUpdated(keeper, _keeper);
        keeper = _keeper;
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

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Roll only after the full fixed 7-day Nest epoch has elapsed.
    function rollEpoch() external onlyKeeper {
        Epoch storage cur = epochs[currentEpochId];
        if (block.timestamp < cur.end) revert EpochStillOpen();
        if (cur.closed) revert EpochNotOpen();

        cur.closed = true;
        emit EpochClosed(currentEpochId);

        currentEpochId += 1;
        currentEpochStart = block.timestamp;
        _openEpoch(currentEpochId, currentEpochStart);
    }

    /// @notice Deposit NEST for the current epoch. hNEST remains in this gate until the 8-day delay expires.
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

        // A user's last deposit in this epoch determines the minimum user-level 8-day delay.
        uint256 unlockAt = block.timestamp + HNEST_MINT_DELAY;
        if (unlockAt < ep.claimableAt) unlockAt = ep.claimableAt;
        if (unlockAt > userClaimableAt[currentEpochId][msg.sender]) {
            userClaimableAt[currentEpochId][msg.sender] = unlockAt;
        }

        emit Deposited(currentEpochId, msg.sender, nestAmount, minted, userClaimableAt[currentEpochId][msg.sender]);
    }

    /// @notice After the 7-day Nest epoch settles, keeper sends this epoch's new-deposit HYPE.
    ///         Protocol takes feeBps; remainder is pro-rata to this epoch's depositors.
    function allocateHype(uint256 epochId, uint256 amount) external onlyKeeper nonReentrant {
        Epoch storage ep = epochs[epochId];
        if (!ep.closed && block.timestamp < ep.end) revert EpochStillOpen();
        ep.closed = true;
        if (ep.hypeFinal) revert HypeAlreadyFinal();

        uint256 fee;
        uint256 net;
        if (amount > 0) {
            hypeToken.safeTransferFrom(msg.sender, address(this), amount);
            fee = (amount * feeBps) / BASIS_POINTS;
            net = amount - fee;
            if (fee > 0) {
                hypeToken.safeTransfer(feeRecipient, fee);
            }
            ep.hypeAllocated += net;
            ep.hypeFeeTaken += fee;
        }
        ep.hypeFinal = true;
        emit HypeAllocated(epochId, amount, fee, net);
    }

    /// @notice Once the epoch is final and the user's 8-day delay has expired, release hNEST + HYPE.
    function claim(uint256 epochId) external nonReentrant {
        Epoch storage ep = epochs[epochId];
        if (!ep.hypeFinal) revert EpochNotOpen();

        uint256 owedH = hNestOwed[epochId][msg.sender];
        if (owedH == 0) revert NothingOwed();
        if (hNestTaken[epochId][msg.sender]) revert AlreadyTaken();

        uint256 claimableAt = userClaimableAt[epochId][msg.sender];
        if (block.timestamp < claimableAt) revert MintDelayActive(claimableAt);

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
        claimable = ep.hypeFinal
            && !hNestTaken[epochId][user]
            && hNestOwed[epochId][user] > 0
            && block.timestamp >= userClaimableAt[epochId][user];
    }

    function _openEpoch(uint256 epochId, uint256 start) internal {
        uint256 end = start + NEST_EPOCH_LENGTH;
        uint256 claimableAt = start + HNEST_MINT_DELAY;
        epochs[epochId].start = start;
        epochs[epochId].end = end;
        epochs[epochId].claimableAt = claimableAt;
        emit EpochOpened(epochId, start, end, claimableAt);
    }
}
