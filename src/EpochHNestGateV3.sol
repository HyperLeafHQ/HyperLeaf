// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {HNestCirculation} from "./HNestCirculation.sol";

interface INestVaultDepositV3 {
    function deposit(uint256 nestAmount) external;
    function hNest() external view returns (address);
    function nestToken() external view returns (address);
    function pendingResidualHype(address user) external view returns (uint256);
    function claimResidualHype() external;
    function depositGate() external view returns (address);
}

/// @title EpochHNestGateV3
/// @notice Upgradeable Gate (UUPS). One proxy, one hNEST. Accounting fixes
///         ship as implementation upgrades. The veNEST vault stays immutable:
///         an upgradeable vault could rewrite NFT custody.
///
///         Issue #110. A week's HYPE is not credited to whoever still sits in
///         the Gate when the transfer lands.
///
///         - 8-day claim delay is unchanged. A deposit still spans two Nest weeks.
///         - New-deposit HYPE is only the deposit epoch's `hypeAllocated`.
///         - Later weeks pay carry growth on hNEST-seconds held that week,
///           including users who already took their hNEST out.
///         - `bookEpoch` is the only credit. The epoch must have ended, it can
///           be booked once, and it must be booked before `finalizeHype`.
///         - Unassigned WHYPE is never forwarded to feeRecipient.
///
/// @custom:oz-upgrades-unsafe-allow constructor
contract EpochHNestGateV3 is Initializable, UUPSUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant VERSION = 3;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant NEST_EPOCH_LENGTH = 7 days;
    uint256 public constant HNEST_MINT_DELAY = 8 days;
    uint256 public constant HYPE_FINALIZE_DELAY = 1 days;
    uint256 public constant GROWTH_INDEX_SCALE = 1e18;
    uint256 public constant MAX_TRANCHES_PER_EPOCH = 32;
    uint256 public constant MAX_ROLLS_PER_TX = 60;

    IERC20 public nestToken;
    IERC20 public hypeToken;
    IERC20 public hNest;
    INestVaultDepositV3 public vault;

    address public owner;
    address public pendingOwner;
    address public keeper;
    address public guardian;
    bool public paused;

    uint256 public currentEpochId;
    uint256 public carryHNest;
    uint256 public lastCarryPoke;
    uint256 public unassignedHype;

    struct Epoch {
        uint256 start;
        uint256 end;
        uint256 claimableAt;
        uint256 totalNest;
        uint256 totalHNest;
        uint256 unclaimedHNest;
        uint256 hypeAllocated;
        bool closed;
        bool hypeFinal;
    }

    struct DepositTranche {
        uint256 nestAmount;
        uint256 hNestAmount;
        uint256 claimableAt;
        uint256 depositedAt;
        uint256 claimedAt;
        bool claimed;
    }

    mapping(uint256 => Epoch) public epochs;
    /// @dev hNEST-seconds of carry (older deposits) during the epoch.
    mapping(uint256 => uint256) public carryPointSupply;
    /// @dev hNEST-seconds of this epoch's own deposits. Sizes the new-deposit pot.
    mapping(uint256 => uint256) public holdPointSupply;
    mapping(uint256 => bool) public weekBooked;
    mapping(uint256 => uint256) public growthPerPoint;
    mapping(uint256 => uint256) public growthAccounted;

    mapping(uint256 => mapping(address => uint256)) public nestIn;
    mapping(uint256 => mapping(address => uint256)) public hNestOwed;
    mapping(uint256 => mapping(address => DepositTranche[])) internal _tranches;
    /// @dev week => depositEpoch => user => tranche => growth already paid.
    mapping(uint256 => mapping(uint256 => mapping(address => mapping(uint256 => uint256)))) public trancheGrowthPaid;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event EpochOpened(uint256 indexed epochId, uint256 start, uint256 end, uint256 claimableAt);
    event EpochClosed(uint256 indexed epochId);
    event Deposited(
        uint256 indexed epochId, address indexed user, uint256 nestAmount, uint256 hNestMinted, uint256 claimableAt
    );
    event ResidualSynced(uint256 pulled, uint256 unassigned);
    event UnassignedFunded(address indexed from, uint256 amount);
    event EpochBooked(uint256 indexed epochId, uint256 amount, uint256 newDeposit, uint256 growth, uint256 perPoint);
    event HypeFinalized(uint256 indexed epochId, uint256 net);
    event Claimed(
        uint256 indexed epochId, address indexed user, uint256 hNestAmount, uint256 newDepositHype, uint256 growthHype
    );
    event GrowthClaimed(address indexed user, uint256 amount);

    error ZeroAmount();
    error ZeroAddress();
    error NotOwner();
    error NotKeeper();
    error NotGuardian();
    error EpochNotOpen();
    error EpochStillOpen();
    error MintDelayActive(uint256 claimableAt);
    error AlreadyTaken();
    error NothingOwed();
    error HypeAlreadyFinal();
    error HypeNotFinal();
    error FinalizeTooEarly(uint256 earliest);
    error EpochNotClosed();
    error TooManyTranches();
    error UnknownTranche();
    error AlreadyBooked();
    error AmountExceedsUnassigned(uint256 amount, uint256 unassigned);
    error NothingToAttribute();
    error GrowthTooSmall();
    error WeekNotBooked();
    error EpochsBehind();
    error EnforcedPause();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert NotKeeper();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _vault,
        address _hypeToken,
        address _keeper,
        address _guardian
    ) external initializer {
        if (
            _owner == address(0) || _vault == address(0) || _hypeToken == address(0) || _keeper == address(0)
                || _guardian == address(0)
        ) revert ZeroAddress();
        owner = _owner;
        vault = INestVaultDepositV3(_vault);
        nestToken = IERC20(vault.nestToken());
        hNest = IERC20(vault.hNest());
        hypeToken = IERC20(_hypeToken);
        keeper = _keeper;
        guardian = _guardian;
        nestToken.forceApprove(_vault, type(uint256).max);
        _openEpoch(0, block.timestamp);
        emit OwnershipTransferred(address(0), _owner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotOwner();
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
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

    function pause() external {
        if (msg.sender != guardian && msg.sender != owner) revert NotGuardian();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function rollEpoch() external {
        if (block.timestamp < epochs[currentEpochId].end) revert EpochStillOpen();
        _rollEpoch();
    }

    function deposit(uint256 nestAmount) external nonReentrant whenNotPaused {
        if (nestAmount == 0) revert ZeroAmount();
        _catchUp();
        _syncResidual();
        Epoch storage ep = epochs[currentEpochId];
        if (ep.closed) revert EpochNotOpen();
        _poke(block.timestamp);

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
        ts.push(
            DepositTranche({
                nestAmount: nestAmount,
                hNestAmount: minted,
                claimableAt: unlockAt,
                depositedAt: block.timestamp,
                claimedAt: 0,
                claimed: false
            })
        );
        emit Deposited(currentEpochId, msg.sender, nestAmount, minted, unlockAt);
    }

    /// @notice Pull vault residual into `unassignedHype`. Does not credit anyone.
    function syncResidual() external nonReentrant returns (uint256 pulled) {
        pulled = _syncResidual();
    }

    /// @notice Keeper tops up the unassigned pot. Still has to `bookEpoch`.
    function fundUnassigned(uint256 amount) external onlyKeeper nonReentrant {
        if (amount == 0) revert ZeroAmount();
        hypeToken.safeTransferFrom(msg.sender, address(this), amount);
        unassignedHype += amount;
        emit UnassignedFunded(msg.sender, amount);
    }

    /// @notice Credit `amount` of unassigned WHYPE to one ended epoch, once.
    ///         Split by hNEST-seconds: this epoch's deposits vs older carry.
    function bookEpoch(uint256 epochId, uint256 amount) external onlyKeeper nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Epoch storage ep = epochs[epochId];
        if (ep.start == 0) revert EpochNotOpen();
        if (block.timestamp < ep.end) revert EpochStillOpen();
        if (ep.hypeFinal) revert HypeAlreadyFinal();
        if (weekBooked[epochId]) revert AlreadyBooked();
        if (amount > unassignedHype) revert AmountExceedsUnassigned(amount, unassignedHype);

        if (epochId == currentEpochId) _poke(ep.end);

        uint256 hold = holdPointSupply[epochId];
        uint256 carryPts = carryPointSupply[epochId];
        uint256 total = hold + carryPts;
        if (total == 0) revert NothingToAttribute();

        uint256 newShare = Math.mulDiv(amount, hold, total);
        uint256 growthShare = amount - newShare;
        uint256 per;
        uint256 accounted;
        if (growthShare > 0) {
            per = Math.mulDiv(growthShare, GROWTH_INDEX_SCALE, carryPts);
            if (per == 0) revert GrowthTooSmall();
            accounted = Math.mulDiv(per, carryPts, GROWTH_INDEX_SCALE);
            growthPerPoint[epochId] = per;
            growthAccounted[epochId] = accounted;
        }
        uint256 dust = growthShare - accounted;
        unassignedHype = unassignedHype - amount + dust;
        ep.hypeAllocated += newShare;
        weekBooked[epochId] = true;
        emit EpochBooked(epochId, amount, newShare, accounted, per);
    }

    function finalizeHype(uint256 epochId) external {
        Epoch storage ep = epochs[epochId];
        if (ep.start == 0) revert EpochNotOpen();
        if (!ep.closed) revert EpochNotClosed();
        if (ep.hypeFinal) revert HypeAlreadyFinal();
        uint256 earliest = ep.end + HYPE_FINALIZE_DELAY;
        if (block.timestamp < earliest) revert FinalizeTooEarly(earliest);
        if ((ep.totalNest > 0 || carryPointSupply[epochId] > 0) && !weekBooked[epochId]) revert WeekNotBooked();
        ep.hypeFinal = true;
        emit HypeFinalized(epochId, ep.hypeAllocated);
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

    /// @notice Growth for hNEST that already left the Gate. Does not move hNEST.
    function claimGrowth(uint256 depositEpoch, uint256 trancheIndex) external nonReentrant {
        DepositTranche[] storage ts = _tranches[depositEpoch][msg.sender];
        if (trancheIndex >= ts.length) revert UnknownTranche();
        _catchUp();
        _syncResidual();
        uint256 paid = _payTrancheGrowth(depositEpoch, msg.sender, trancheIndex);
        if (paid == 0) revert NothingOwed();
        hypeToken.safeTransfer(msg.sender, paid);
        emit GrowthClaimed(msg.sender, paid);
    }

    function depositTranches(uint256 epochId, address user, uint256 i)
        external
        view
        returns (
            uint256 nestAmount,
            uint256 hNestAmount,
            uint256 claimableAt_,
            uint256 depositedAt,
            uint256 claimedAt,
            bool claimed
        )
    {
        DepositTranche storage t = _tranches[epochId][user][i];
        return (t.nestAmount, t.hNestAmount, t.claimableAt, t.depositedAt, t.claimedAt, t.claimed);
    }

    function trancheCount(uint256 epochId, address user) external view returns (uint256) {
        return _tranches[epochId][user].length;
    }

    function tranchePoints(uint256 week, uint256 depositEpoch, address user, uint256 i)
        external
        view
        returns (uint256)
    {
        if (depositEpoch >= week) return 0;
        return _oneTranchePoints(week, _tranches[depositEpoch][user][i]);
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
            if (!ts[i].claimed) {
                hNestAmount += ts[i].hNestAmount;
                if (ep.hypeFinal && ep.totalNest > 0) {
                    newDepositHype += Math.mulDiv(ts[i].nestAmount, ep.hypeAllocated, ep.totalNest);
                }
                if (ep.hypeFinal && block.timestamp >= ts[i].claimableAt) claimable = true;
            }
            growthHype += _unpaidTrancheGrowth(epochId, user, i);
        }
    }

    function _claimTranche(uint256 epochId, uint256 trancheIndex) internal {
        _catchUp();
        _syncResidual();
        Epoch storage ep = epochs[epochId];
        if (!ep.hypeFinal) revert HypeNotFinal();
        DepositTranche[] storage ts = _tranches[epochId][msg.sender];
        if (trancheIndex >= ts.length) revert UnknownTranche();
        DepositTranche storage t = ts[trancheIndex];
        if (t.claimed) revert AlreadyTaken();
        if (block.timestamp < t.claimableAt) revert MintDelayActive(t.claimableAt);

        _poke(block.timestamp);
        t.claimed = true;
        t.claimedAt = block.timestamp;
        hNestOwed[epochId][msg.sender] -= t.hNestAmount;
        ep.unclaimedHNest -= t.hNestAmount;
        if (epochId < currentEpochId) carryHNest -= t.hNestAmount;

        uint256 newDepositPay;
        if (ep.hypeAllocated > 0 && ep.totalNest > 0) {
            newDepositPay = Math.mulDiv(t.nestAmount, ep.hypeAllocated, ep.totalNest);
        }
        uint256 growthPay = _payTrancheGrowth(epochId, msg.sender, trancheIndex);
        if (newDepositPay > 0) hypeToken.safeTransfer(msg.sender, newDepositPay);
        if (growthPay > 0) hypeToken.safeTransfer(msg.sender, growthPay);
        hNest.safeTransfer(msg.sender, t.hNestAmount);
        emit Claimed(epochId, msg.sender, t.hNestAmount, newDepositPay, growthPay);
    }

    function _payTrancheGrowth(uint256 depositEpoch, address user, uint256 trancheIndex)
        internal
        returns (uint256 paid)
    {
        uint256 last = currentEpochId;
        for (uint256 week = depositEpoch + 1; week <= last; ++week) {
            uint256 per = growthPerPoint[week];
            if (per == 0) continue;
            uint256 pts = _oneTranchePoints(week, _tranches[depositEpoch][user][trancheIndex]);
            if (pts == 0) continue;
            uint256 gross = Math.mulDiv(pts, per, GROWTH_INDEX_SCALE);
            uint256 already = trancheGrowthPaid[week][depositEpoch][user][trancheIndex];
            if (gross <= already) continue;
            uint256 owe = gross - already;
            trancheGrowthPaid[week][depositEpoch][user][trancheIndex] = gross;
            paid += owe;
        }
    }

    function _unpaidTrancheGrowth(uint256 depositEpoch, address user, uint256 trancheIndex)
        internal
        view
        returns (uint256 unpaid)
    {
        uint256 last = currentEpochId;
        for (uint256 week = depositEpoch + 1; week <= last; ++week) {
            uint256 per = growthPerPoint[week];
            if (per == 0) continue;
            uint256 pts = _oneTranchePoints(week, _tranches[depositEpoch][user][trancheIndex]);
            if (pts == 0) continue;
            uint256 gross = Math.mulDiv(pts, per, GROWTH_INDEX_SCALE);
            uint256 already = trancheGrowthPaid[week][depositEpoch][user][trancheIndex];
            if (gross > already) unpaid += gross - already;
        }
    }

    function _oneTranchePoints(uint256 week, DepositTranche storage t) internal view returns (uint256) {
        uint256 start = epochs[week].start;
        uint256 end = epochs[week].end;
        if (start == 0 || end <= start) return 0;
        uint256 holdEnd = t.claimed ? (t.claimedAt < end ? t.claimedAt : end) : (block.timestamp < end ? block.timestamp : end);
        if (holdEnd <= start) return 0;
        return t.hNestAmount * (holdEnd - start);
    }

    function _catchUp() internal {
        uint256 guard;
        while (block.timestamp >= epochs[currentEpochId].end) {
            if (guard++ == MAX_ROLLS_PER_TX) revert EpochsBehind();
            _rollEpoch();
        }
    }

    function _rollEpoch() internal {
        Epoch storage cur = epochs[currentEpochId];
        _poke(cur.end);
        if (!cur.closed) {
            cur.closed = true;
            carryHNest += cur.unclaimedHNest;
            emit EpochClosed(currentEpochId);
        }
        currentEpochId += 1;
        _openEpoch(currentEpochId, cur.end);
    }

    function _openEpoch(uint256 epochId, uint256 start) internal {
        uint256 end = HNestCirculation.epochEnd(start);
        if (end <= start) end = start + NEST_EPOCH_LENGTH;
        uint256 claimableAt_ = HNestCirculation.claimableAt(start);
        Epoch storage ep = epochs[epochId];
        ep.start = start;
        ep.end = end;
        ep.claimableAt = claimableAt_;
        lastCarryPoke = start;
        emit EpochOpened(epochId, start, end, claimableAt_);
    }

    /// @dev Integrate carry and current-epoch deposits up to `t`, capped at the current epoch end.
    function _poke(uint256 t) internal {
        uint256 e = currentEpochId;
        Epoch storage ep = epochs[e];
        if (lastCarryPoke == 0) lastCarryPoke = ep.start;
        if (t <= lastCarryPoke) return;
        uint256 to = t > ep.end ? ep.end : t;
        if (to <= lastCarryPoke) return;
        uint256 dt = to - lastCarryPoke;
        carryPointSupply[e] += carryHNest * dt;
        holdPointSupply[e] += ep.unclaimedHNest * dt;
        lastCarryPoke = to;
    }

    function _syncResidual() internal returns (uint256 pulled) {
        if (vault.pendingResidualHype(address(this)) == 0) return 0;
        uint256 before = hypeToken.balanceOf(address(this));
        vault.claimResidualHype();
        pulled = hypeToken.balanceOf(address(this)) - before;
        if (pulled == 0) return 0;
        unassignedHype += pulled;
        emit ResidualSynced(pulled, unassignedHype);
    }

    uint256[48] private __gap;
}
