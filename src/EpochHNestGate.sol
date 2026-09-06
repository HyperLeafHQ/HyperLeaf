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
 * @notice Mint-delay in front of NestVault. Circulating hNEST stays a standard ERC-20.
 *
 * Why this exists (Nest HYPE rule, NOT generic MasterChef):
 *   Nest pays weekly HYPE to veNEST that *increased this epoch* (new deposits +
 *   compound increment). Fungible hNEST cannot remember "I am this week's new
 *   principal". If we MasterChef that HYPE to every current holder, DEX buyers of
 *   old hNEST steal the new-depositor HYPE and new deposits get diluted.
 *
 * What this contract is NOT:
 *   - It does NOT freeze hNEST transfers.
 *   - It does NOT make hNEST a non-standard ERC-20.
 *   - DEX pools still trade ordinary hNEST.
 *
 * Flow:
 *   1. User deposits NEST here. Vault mints hNEST to THIS contract.
 *   2. After the Nest week, keeper sends that week's *new-deposit* HYPE and
 *      calls allocateHype. Protocol takes feeBps (default 1%); rest is pro-rata
 *      to this epoch's depositors.
 *   3. User claims: transferable hNEST + that week's HYPE. From then on they
 *      hold seasoned hNEST (old principal) like everyone else.
 *
 * Compound-increment HYPE (the small slice on already-seasoned principal) is
 * NOT allocated here — NestVault MasterChef residual path / a later splitter
 * handles that. Keeper must not dump the whole Nest HYPE blob into this gate.
 *
 * 1% protocol fee: staking yield only. No fee on NEST in/out besides gas.
 */
contract EpochHNestGate is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_FEE_BPS = 500;

    IERC20 public immutable nestToken;
    IERC20 public immutable hypeToken;
    IERC20 public immutable hNest;
    INestVaultDeposit public immutable vault;

    address public keeper;
    address public feeRecipient;
    uint256 public feeBps = 100; // 1%
    uint256 public epochLength = 7 days;
    uint256 public currentEpochId;
    uint256 public currentEpochStart;

    struct Epoch {
        uint256 start;
        uint256 end;
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
    mapping(uint256 => mapping(address => bool)) public hNestTaken;
    mapping(uint256 => mapping(address => bool)) public hypeTaken;

    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event EpochOpened(uint256 indexed epochId, uint256 start, uint256 end);
    event EpochClosed(uint256 indexed epochId);
    event Deposited(uint256 indexed epochId, address indexed user, uint256 nestAmount, uint256 hNestMinted);
    event HypeAllocated(uint256 indexed epochId, uint256 gross, uint256 fee, uint256 net);
    event Claimed(uint256 indexed epochId, address indexed user, uint256 hNestAmount, uint256 hypeAmount);

    error ZeroAmount();
    error ZeroAddress();
    error NotKeeper();
    error EpochNotOpen();
    error EpochStillOpen();
    error AlreadyTaken();
    error NothingOwed();
    error HypeAlreadyFinal();
    error BadEpochLength();
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
        epochs[0].start = block.timestamp;
        epochs[0].end = block.timestamp + epochLength;
        emit EpochOpened(0, epochs[0].start, epochs[0].end);
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

    function setEpochLength(uint256 _len) external onlyOwner {
        if (_len < 1 days || _len > 30 days) revert BadEpochLength();
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

    /// @notice Deposit NEST for the CURRENT epoch. hNEST stays in this contract until claim.
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

        emit Deposited(currentEpochId, msg.sender, nestAmount, minted);
    }

    /// @notice After Nest week settles, keeper sends THIS EPOCH's new-deposit HYPE.
    ///         Protocol takes feeBps; remainder is pro-rata to nestIn of this epoch only.
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

    /// @notice After hypeFinal, user receives standard transferable hNEST + pro-rata HYPE.
    function claim(uint256 epochId) external nonReentrant {
        Epoch storage ep = epochs[epochId];
        if (!ep.hypeFinal) revert EpochNotOpen();

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
