// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {HNest} from "./HNest.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IHevAdapter} from "./interfaces/IHevAdapter.sol";
import {INestVaultHype} from "./interfaces/INestVaultHype.sol";
import {INestMerkleAirdrop} from "./interfaces/INestMerkleAirdrop.sol";
import {HyperEVMAddresses} from "./config/HyperEVMAddresses.sol";

/**
 * @title NestVaultC1
 * @notice Next Nest vault. C1: no redeem, no idle buffer, full lock + HEV attach.
 *         Exit is Leaf Market. Circulation is EpochHNestGate (8d).
 *
 *         Live v1 0x4f6615… is abandoned (test TVL). Do not patch it.
 *
 *         HYPE: anyone may Merkle.claim the vault's leaf (tokens always land here).
 *         Inbound WHYPE is not holder yield until settleInboundHype takes 1%.
 *         veNEST growth → bookVerifiedYield so later deposits are not 1:1.
 */
contract NestVaultC1 is Ownable2Step, ReentrancyGuard, Pausable, IERC721Receiver, INestVaultHype {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LOCK_DURATION = 26 weeks;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_FEE_BPS = 500;
    uint256 public constant MAX_YIELD_BOOK_BPS = 1_000;

    IERC20 public immutable nestToken;
    IVotingEscrow public immutable veNEST;
    IERC20 public immutable hypeToken;
    HNest public immutable hNest;

    IHevAdapter public hevAdapter;
    INestMerkleAirdrop public merkleAirdrop;
    address public keeper;
    address public guardian;
    address public feeRecipient;
    uint256 public feeBps = 100;
    uint256 public depositCap;
    bool public depositsEnabled;
    address public depositGate;

    uint256[] public veNFTIds;
    mapping(uint256 => bool) public inHev;
    mapping(uint256 => uint256) public nestPrincipal;
    uint256 public totalNestLocked;
    mapping(uint256 => uint256) public bookedLockedShare;
    uint256 public yieldBookedThisEpoch;
    uint256 public yieldBookEpochStart;

    mapping(address => uint256) public hypeRewardDebt;
    uint256 public accHypePerShare;
    /// @dev Holder-owned WHYPE still in the vault (net of fee, not yet claimed).
    uint256 public hypeAccounted;
    uint256 public totalHypeDistributed;

    /// @dev Time-weighted HYPE. A week freezes at most once per `HYPE_EPOCH_MIN`.
    ///      HYPE that arrives after that freeze is added to the frozen week.
    ///      Catch-up is explicit: transfers revert until `checkpointHype` has
    ///      walked every closed week at the balance still held. `HYPE_CREDIT_BATCH`
    ///      is small enough for a 3M-gas block.
    uint256 public constant HYPE_EPOCH_MIN = 7 days;
    uint256 public constant HYPE_CREDIT_BATCH = 16;
    uint256 public lastHypeGlobal;
    uint256 public lastHypeSettle;
    uint256 public hypePointsSupply;
    uint256 public hypeEpochId;
    mapping(uint256 => uint256) public hypeEpochPot;
    mapping(uint256 => uint256) public hypeEpochPoints;
    mapping(uint256 => uint256) public hypeEpochClosedAt;
    mapping(address => uint256) public hypePoints;
    mapping(address => uint256) public lastHypePoke;
    mapping(address => uint256) public userHypeEpoch;
    mapping(address => uint256) public hypeStored;
    /// @dev The one frozen week whose pot can still grow. `epoch + 1`, or 0 if none.
    mapping(address => uint256) public hypeTipEpochPlusOne;
    mapping(address => uint256) public hypeTipPts;
    mapping(address => uint256) public hypeTipPaid;

    event Deposited(address indexed user, uint256 nestAmount, uint256 hNestMinted);
    event InboundHypeSettled(uint256 gross, uint256 fee, uint256 net);
    event HypeEpochClosed(uint256 indexed epochId, uint256 pot, uint256 points);
    /// @dev `received` is the actual WHYPE delta this call brought in — the merkle
    ///      `amount` argument is cumulative, so it would mislead indexers on later weeks.
    event MerkleClaimed(address indexed caller, uint256 received);
    event ResidualHypeClaimed(address indexed user, uint256 amount);
    event YieldBooked(uint256 addedNest, uint256 feeAssets, uint256 feeShares);
    event YieldWrittenDown(uint256 removedNest);
    event HarvestExecuted(uint256 hypeClaimed, uint256 feesTaken);
    event DepositGateUpdated(address indexed gate);
    event DepositsEnabledUpdated(bool enabled);
    event KeeperUpdated(address oldKeeper, address newKeeper);
    event GuardianUpdated(address oldGuardian, address newGuardian);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event DepositCapUpdated(uint256 oldCap, uint256 newCap);
    event HevAdapterUpdated(address oldAdapter, address newAdapter);
    event MerkleAirdropUpdated(address indexed merkle);

    error ZeroAmount();
    error ZeroAddress();
    error NotKeeper();
    error NotGuardianOrOwner();
    error ZeroShares();
    error DepositCapExceeded();
    error FeeTooHigh();
    error OnlyHNest();
    error InvalidHNest();
    error DepositsDisabled();
    error HevAdapterNotSet();
    error HevAdapterChangeWhileLive();
    error OnlyDepositGate();
    error DepositGateFrozen();
    error GateRequired();
    error YieldBookTooLarge(uint256 y, uint256 cap);
    error InvalidBookRange(uint256 start, uint256 end, uint256 length);
    error MerkleNotSet();
    error UnknownNft();
    error ProtectedVeNft();
    error NotCaughtUp(address user);

    modifier onlyKeeper() {
        if (msg.sender != keeper && msg.sender != owner()) revert NotKeeper();
        _;
    }

    modifier onlyGuardianOrOwner() {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardianOrOwner();
        _;
    }

    constructor(
        address _nestToken,
        address _veNEST,
        address _hypeToken,
        address _hevAdapter,
        address _feeRecipient,
        address _keeper,
        address _guardian,
        uint256 _depositCap,
        address _hNest,
        address _merkle
    ) Ownable(msg.sender) {
        if (
            _nestToken == address(0) || _veNEST == address(0) || _hypeToken == address(0) || _feeRecipient == address(0)
                || _keeper == address(0)
        ) revert ZeroAddress();

        nestToken = IERC20(_nestToken);
        veNEST = IVotingEscrow(_veNEST);
        hypeToken = IERC20(_hypeToken);
        hevAdapter = IHevAdapter(_hevAdapter);
        feeRecipient = _feeRecipient;
        keeper = _keeper;
        guardian = _guardian;
        depositCap = _depositCap;
        merkleAirdrop = INestMerkleAirdrop(_merkle);

        if (_hNest == address(0)) {
            hNest = new HNest(address(this));
        } else {
            hNest = HNest(_hNest);
            if (hNest.vault() != address(this)) revert InvalidHNest();
        }
        nestToken.forceApprove(address(veNEST), type(uint256).max);
        lastHypeGlobal = block.timestamp;
        lastHypeSettle = block.timestamp;
    }

    function deposit(uint256 nestAmount) external nonReentrant whenNotPaused {
        if (!depositsEnabled) revert DepositsDisabled();
        if (depositGate == address(0) || msg.sender != depositGate) revert OnlyDepositGate();
        if (nestAmount == 0) revert ZeroAmount();
        if (depositCap > 0 && totalNestLocked + nestAmount > depositCap) revert DepositCapExceeded();

        // Settle inbound WHYPE AND pay the caller's accrued pending before minting.
        // Normally a no-op claim: deposits are gate-only and EpochHNestGate syncs its
        // residual in the same tx before calling deposit. This protects edge paths
        // (gate migration, failed sync) where pending WHYPE would otherwise be zeroed
        // by the post-mint reward-debt overwrite and permanently stranded.
        _claimResidualHypeInternal(msg.sender);

        uint256 totalSupply = hNest.totalSupply();
        uint256 hNestToMint = totalSupply == 0 || totalNestLocked == 0
            ? nestAmount
            : (nestAmount * totalSupply) / totalNestLocked;
        if (hNestToMint == 0) revert ZeroShares();

        nestToken.safeTransferFrom(msg.sender, address(this), nestAmount);
        uint256 tokenId = veNEST.createLockFor(
            nestAmount, MAX_LOCK_DURATION, address(this), false, true, HyperEVMAddresses.HEV_MANAGED_TOKEN_ID
        );
        veNFTIds.push(tokenId);
        nestPrincipal[tokenId] = nestAmount;
        if (address(hevAdapter) != address(0)) {
            veNEST.approve(address(hevAdapter), tokenId);
            hevAdapter.depositVeNFT(tokenId);
            inHev[tokenId] = true;
        }

        totalNestLocked += nestAmount;
        hNest.mint(msg.sender, hNestToMint);
        hypeRewardDebt[msg.sender] = (hNest.balanceOf(msg.sender) * accHypePerShare) / 1e18;
        lastHypePoke[msg.sender] = block.timestamp;
        userHypeEpoch[msg.sender] = hypeEpochId;
        _settleInboundHype();
        emit Deposited(msg.sender, nestAmount, hNestToMint);
    }

    /// @notice Anyone. Submits the vault's merkle leaf to Nest 0x33afCe… claim(0xca21b177).
    ///         `addr_` is always this vault — caller cannot redirect. amount is cumulative.
    ///         Proof length is not fixed (live week-1 was 11). Pause does not block this.
    ///         Emits MerkleClaimed with the actual WHYPE delta received (amount is cumulative,
    ///         so on later weeks the delta is smaller than `amount`).
    function claimMerkle(bytes32[] calldata proof, uint256 amount) external nonReentrant {
        if (address(merkleAirdrop) == address(0)) revert MerkleNotSet();
        uint256 before = hypeToken.balanceOf(address(this));
        merkleAirdrop.claim(proof, address(this), amount);
        uint256 received = hypeToken.balanceOf(address(this)) - before;
        emit MerkleClaimed(msg.sender, received);
        _settleInboundHype();
    }

    /// @notice Anyone. Fees inbound WHYPE (merkle, HEV sweep, or donation) then credits net.
    ///         Unsolicited WHYPE is treated as campaign yield — owner-accepted (audit M-02).
    ///         Not paused: fee collection must stay live if deposits are frozen.
    function settleInboundHype() external nonReentrant {
        _settleInboundHype();
    }

    function harvest() external onlyKeeper nonReentrant {
        if (address(hevAdapter) != address(0) && veNFTIds.length > 0) {
            hevAdapter.sweepResidualHype(veNFTIds, address(this));
        }
        (uint256 gross, uint256 fee,) = _settleInboundHype();
        emit HarvestExecuted(gross, fee);
    }

    /// @notice Full-range wrapper. Fine while the NFT count is small; on HyperEVM's 3M
    ///         small-block gas limit the loop bricks around ~200-300 veNFTs, at which point
    ///         keepers MUST switch to the paginated overload below (~150 is the alert line).
    function bookVerifiedYield() external onlyKeeper nonReentrant {
        _bookVerifiedYield(0, veNFTIds.length);
    }

    /// @notice Paginated keeper path: processes veNFTIds[start:end] only.
    ///         The weekly MAX_YIELD_BOOK_BPS cap still applies cumulatively —
    ///         yieldBookedThisEpoch accumulates across paginated calls within a week.
    function bookVerifiedYield(uint256 start, uint256 end) external onlyKeeper nonReentrant {
        if (start >= end || end > veNFTIds.length) revert InvalidBookRange(start, end, veNFTIds.length);
        _bookVerifiedYield(start, end);
    }

    function _bookVerifiedYield(uint256 start, uint256 end) internal {
        if (address(hevAdapter) == address(0)) revert HevAdapterNotSet();
        uint256 y;
        uint256 down;
        for (uint256 i = start; i < end; ++i) {
            uint256 tokenId = veNFTIds[i];
            if (!inHev[tokenId]) continue;
            uint256 pending = hevAdapter.pendingLockedNestShare(tokenId);
            uint256 booked = bookedLockedShare[tokenId];
            if (pending > booked) {
                y += pending - booked;
                bookedLockedShare[tokenId] = pending;
            } else if (pending < booked) {
                down += booked - pending;
                bookedLockedShare[tokenId] = pending;
            }
        }
        if (down > 0) {
            if (down > totalNestLocked) down = totalNestLocked;
            totalNestLocked -= down;
            emit YieldWrittenDown(down);
        }
        if (y == 0) {
            if (down == 0) revert ZeroShares();
            return;
        }
        if (totalNestLocked > 0) {
            uint256 week = (block.timestamp / 7 days) * 7 days;
            if (week != yieldBookEpochStart) {
                yieldBookEpochStart = week;
                yieldBookedThisEpoch = 0;
            }
            uint256 cap = (totalNestLocked * MAX_YIELD_BOOK_BPS) / BASIS_POINTS;
            if (yieldBookedThisEpoch + y > cap) revert YieldBookTooLarge(y, cap - yieldBookedThisEpoch);
            yieldBookedThisEpoch += y;
        }
        uint256 feeAssets = (y * feeBps) / BASIS_POINTS;
        uint256 supply = hNest.totalSupply();
        totalNestLocked += y;
        uint256 feeShares;
        if (feeAssets > 0 && supply > 0 && totalNestLocked > feeAssets) {
            feeShares = (feeAssets * supply) / (totalNestLocked - feeAssets);
            if (feeShares > 0) {
                _claimResidualHypeInternal(feeRecipient);
                hNest.mint(feeRecipient, feeShares);
                hypeRewardDebt[feeRecipient] = (hNest.balanceOf(feeRecipient) * accHypePerShare) / 1e18;
                lastHypePoke[feeRecipient] = block.timestamp;
                userHypeEpoch[feeRecipient] = hypeEpochId;
            }
        }
        emit YieldBooked(y, feeAssets, feeShares);
    }

    function claimResidualHype() external nonReentrant {
        _settleInboundHype();
        _accrueUser(msg.sender, HYPE_CREDIT_BATCH, false);
        _payout(msg.sender);
    }

    /// @notice Anyone. Walks up to `HYPE_CREDIT_BATCH` closed weeks for `user`.
    function checkpointHype(address user) external nonReentrant {
        _checkpoint(user, HYPE_CREDIT_BATCH);
    }

    /// @notice Same, but the caller chooses the batch. Values above the cap are clipped.
    function checkpointHype(address user, uint256 maxEpochs) external nonReentrant {
        if (maxEpochs == 0 || maxEpochs > HYPE_CREDIT_BATCH) maxEpochs = HYPE_CREDIT_BATCH;
        _checkpoint(user, maxEpochs);
    }

    function settleResidualHype(address user) external override {
        if (msg.sender != address(hNest)) revert OnlyHNest();
        _claimResidualHypeInternal(user);
    }

    function updateDebt(address user) external override {
        if (msg.sender != address(hNest)) revert OnlyHNest();
        hypeRewardDebt[user] = (hNest.balanceOf(user) * accHypePerShare) / 1e18;
        // F-07: do not jump the poke over frozen epochs the batch did not finish.
        if (userHypeEpoch[user] >= hypeEpochId) lastHypePoke[user] = block.timestamp;
    }

    function pendingResidualHype(address user) external view returns (uint256) {
        (uint256 stored,, uint256 snapPend) = _pendingHypeView(user);
        return stored + snapPend;
    }

    function totalVeNFTs() external view returns (uint256) {
        return veNFTIds.length;
    }

    function getVeNFTId(uint256 i) external view returns (uint256) {
        return veNFTIds[i];
    }

    function setDepositGate(address _gate) external onlyOwner {
        if (_gate == address(0)) revert ZeroAddress();
        if (depositGate != address(0)) revert DepositGateFrozen();
        depositGate = _gate;
        emit DepositGateUpdated(_gate);
    }

    function setDepositsEnabled(bool enabled) external onlyOwner {
        if (enabled && depositGate == address(0)) revert GateRequired();
        if (enabled && (address(hevAdapter) == address(0) || address(merkleAirdrop) == address(0))) {
            revert MerkleNotSet();
        }
        depositsEnabled = enabled;
        emit DepositsEnabledUpdated(enabled);
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

    function setFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        emit FeeUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function setDepositCap(uint256 _depositCap) external onlyOwner {
        emit DepositCapUpdated(depositCap, _depositCap);
        depositCap = _depositCap;
    }

    function setHevAdapter(address _hevAdapter) external onlyOwner {
        if (_hevAdapter == address(0)) revert ZeroAddress();
        if (totalNestLocked != 0) revert HevAdapterChangeWhileLive();
        emit HevAdapterUpdated(address(hevAdapter), _hevAdapter);
        hevAdapter = IHevAdapter(_hevAdapter);
    }

    function setMerkleAirdrop(address _merkle) external onlyOwner {
        if (totalNestLocked != 0) revert HevAdapterChangeWhileLive();
        merkleAirdrop = INestMerkleAirdrop(_merkle);
        emit MerkleAirdropUpdated(_merkle);
    }

    function pause() external onlyGuardianOrOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external view returns (bytes4) {
        if (msg.sender != address(veNEST)) revert UnknownNft();
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Owner can pull a stray NFT. Registered veNEST positions cannot be rescued.
    function recoverERC721(address token, uint256 tokenId, address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (token == address(veNEST) && (nestPrincipal[tokenId] != 0 || inHev[tokenId])) {
            revert ProtectedVeNft();
        }
        IERC721(token).safeTransferFrom(address(this), to, tokenId);
    }

    /// @dev Inbound WHYPE: 1% fee, 99% to holders.
    ///      Before the first week freezes, same-block and intra-week HYPE uses the
    ///      spot index so a deposit can settle immediately.
    ///      Once a week freezes, later HYPE is added to that frozen point set until
    ///      the next week freezes. A 1-wei settle cannot hand the week's pot to a
    ///      buyer who shows up afterwards.
    function _settleInboundHype() internal returns (uint256 gross, uint256 fee, uint256 net) {
        uint256 bal = hypeToken.balanceOf(address(this));
        if (bal <= hypeAccounted) return (0, 0, 0);
        uint256 supply = hNest.totalSupply();
        if (supply == 0) return (0, 0, 0);
        uint256 inbound = bal - hypeAccounted;
        fee = (inbound * feeBps) / BASIS_POINTS;
        net = inbound - fee;
        _accrueGlobal();
        bool weekReady = hypePointsSupply > 0
            && (lastHypeSettle == 0 || block.timestamp >= lastHypeSettle + HYPE_EPOCH_MIN);
        if (weekReady) return _freezeEpoch(inbound, fee, net);
        if (hypeEpochId > 0) return _addToFrozenEpoch(inbound, fee, net);

        uint256 deltaAcc = (net * 1e18) / supply;
        if (deltaAcc == 0) return (0, 0, 0);
        if (fee > 0) hypeToken.safeTransfer(feeRecipient, fee);
        uint256 distributed = (deltaAcc * supply) / 1e18;
        accHypePerShare += deltaAcc;
        hypeAccounted += distributed;
        emit InboundHypeSettled(distributed + fee, fee, distributed);
        return (distributed + fee, fee, distributed);
    }

    /// @dev Lock the current point set. Later inbound stays on this epoch until the next freeze.
    function _freezeEpoch(uint256 inbound, uint256 fee, uint256 net)
        internal
        returns (uint256 gross, uint256 feeOut, uint256 netOut)
    {
        uint256 pts = hypePointsSupply;
        uint256 e = hypeEpochId;
        hypeEpochPoints[e] = pts;
        hypeEpochClosedAt[e] = block.timestamp;
        if (net > 0) {
            hypeEpochPot[e] = net;
            if (fee > 0) hypeToken.safeTransfer(feeRecipient, fee);
            hypeAccounted += net;
            emit InboundHypeSettled(inbound, fee, net);
            gross = inbound;
            feeOut = fee;
            netOut = net;
        }
        emit HypeEpochClosed(e, hypeEpochPot[e], pts);
        hypeEpochId = e + 1;
        hypePointsSupply = 0;
        lastHypeGlobal = block.timestamp;
        lastHypeSettle = block.timestamp;
    }

    /// @dev HYPE after a freeze belongs to the frozen holders, not to a new spot balance.
    function _addToFrozenEpoch(uint256 inbound, uint256 fee, uint256 net)
        internal
        returns (uint256 gross, uint256 feeOut, uint256 netOut)
    {
        uint256 e = hypeEpochId - 1;
        uint256 pts = hypeEpochPoints[e];
        if (pts == 0 || net == 0) return (0, 0, 0);
        hypeEpochPot[e] += net;
        if (fee > 0) hypeToken.safeTransfer(feeRecipient, fee);
        hypeAccounted += net;
        emit InboundHypeSettled(inbound, fee, net);
        return (inbound, fee, net);
    }

    function _checkpoint(address user, uint256 maxEpochs) internal {
        _settleInboundHype();
        _accrueUser(user, maxEpochs, false);
        _payout(user);
    }

    /// @dev Transfer, deposit, and yield-fee mint. Reverts if closed weeks are still unpaid.
    function _claimResidualHypeInternal(address user) internal {
        _settleInboundHype();
        _accrueUser(user, 0, true);
        _payout(user);
    }

    function _payout(address user) internal {
        uint256 userBalance = hNest.balanceOf(user);
        uint256 accrued = (userBalance * accHypePerShare) / 1e18;
        uint256 snapPend = accrued > hypeRewardDebt[user] ? accrued - hypeRewardDebt[user] : 0;
        hypeRewardDebt[user] = accrued;
        uint256 pending = hypeStored[user] + snapPend;
        hypeStored[user] = 0;
        if (pending > 0) {
            hypeToken.safeTransfer(user, pending);
            if (hypeAccounted >= pending) hypeAccounted -= pending;
            else hypeAccounted = 0;
            totalHypeDistributed += pending;
            emit ResidualHypeClaimed(user, pending);
        }
    }

    function _accrueUser(address user, uint256 maxEpochs, bool strict) internal {
        if (user == address(0)) return;
        _accrueGlobal();
        uint256 bal = hNest.balanceOf(user);
        if (lastHypePoke[user] == 0) {
            lastHypePoke[user] = block.timestamp;
            userHypeEpoch[user] = hypeEpochId;
            return;
        }
        _payTip(user);
        if (userHypeEpoch[user] < hypeEpochId) {
            if (strict) revert NotCaughtUp(user);
            _creditClosedEpochs(user, bal, maxEpochs);
        }
        uint256 last = lastHypePoke[user];
        if (userHypeEpoch[user] == hypeEpochId && block.timestamp > last) {
            hypePoints[user] += bal * (block.timestamp - last);
            lastHypePoke[user] = block.timestamp;
        }
    }

    function _creditClosedEpochs(address user, uint256 bal, uint256 maxEpochs) internal {
        uint256 cursor = userHypeEpoch[user];
        uint256 last = lastHypePoke[user];
        uint256 pts = hypePoints[user];
        uint256 storedAdd;
        uint256 n;
        while (cursor < hypeEpochId && n < maxEpochs) {
            uint256 e = cursor;
            uint256 closeT = hypeEpochClosedAt[e];
            if (closeT > last) pts += bal * (closeT - last);
            uint256 tot = hypeEpochPoints[e];
            uint256 pot = hypeEpochPot[e];
            uint256 gross = (pts > 0 && tot > 0 && pot > 0) ? (pts * pot) / tot : 0;
            storedAdd += gross;
            if (e + 1 == hypeEpochId) {
                hypeTipEpochPlusOne[user] = e + 1;
                hypeTipPts[user] = pts;
                hypeTipPaid[user] = gross;
            }
            pts = 0;
            last = closeT;
            cursor = e + 1;
            unchecked {
                ++n;
            }
        }
        userHypeEpoch[user] = cursor;
        lastHypePoke[user] = last;
        hypePoints[user] = pts;
        if (storedAdd > 0) hypeStored[user] += storedAdd;
    }

    function _payTip(address user) internal {
        uint256 mark = hypeTipEpochPlusOne[user];
        if (mark == 0) return;
        uint256 e = mark - 1;
        uint256 pts = hypeTipPts[user];
        uint256 tot = hypeEpochPoints[e];
        uint256 pot = hypeEpochPot[e];
        uint256 gross = (pts > 0 && tot > 0 && pot > 0) ? (pts * pot) / tot : 0;
        uint256 paid = hypeTipPaid[user];
        if (gross > paid) hypeStored[user] += gross - paid;
        if (e + 1 < hypeEpochId) {
            hypeTipEpochPlusOne[user] = 0;
            hypeTipPts[user] = 0;
            hypeTipPaid[user] = 0;
        } else {
            hypeTipPaid[user] = gross;
        }
    }
        function _accrueGlobal() internal {
        if (lastHypeGlobal == 0) lastHypeGlobal = block.timestamp;
        if (block.timestamp <= lastHypeGlobal) return;
        uint256 dt = block.timestamp - lastHypeGlobal;
        uint256 supply = hNest.totalSupply();
        if (supply > 0) hypePointsSupply += supply * dt;
        lastHypeGlobal = block.timestamp;
    }

    function _pendingHypeView(address user)
        internal
        view
        returns (uint256 stored, uint256 snapAcc, uint256 snapPend)
    {
        stored = hypeStored[user];
        uint256 supply = hNest.totalSupply();
        uint256 acc = accHypePerShare;
        uint256 ptsSupply = hypePointsSupply;
        uint256 lastG = lastHypeGlobal;
        uint256 epoch = hypeEpochId;
        uint256 balTok = hypeToken.balanceOf(address(this));
        uint256 inbound;
        if (balTok > hypeAccounted && supply > 0) {
            inbound = balTok - hypeAccounted;
        }
        uint256 dt = block.timestamp > lastG ? block.timestamp - lastG : 0;
        uint256 openPts = ptsSupply + supply * dt;
        uint256 userPts = hypePoints[user];
        uint256 last = lastHypePoke[user];
        uint256 userEpoch = userHypeEpoch[user];
        uint256 userBal = hNest.balanceOf(user);
        if (last == 0) {
            last = block.timestamp;
            userEpoch = epoch;
        }
        uint256 addEpoch = type(uint256).max;
        uint256 addNet;
        if (inbound > 0) {
            uint256 fee = (inbound * feeBps) / BASIS_POINTS;
            uint256 net = inbound - fee;
            bool weekReady = openPts > 0
                && (lastHypeSettle == 0 || block.timestamp >= lastHypeSettle + HYPE_EPOCH_MIN);
            if (!weekReady && epoch > 0) {
                addEpoch = epoch - 1;
                addNet = net;
            } else if (!weekReady && epoch == 0) {
                uint256 deltaAcc = supply == 0 ? 0 : (net * 1e18) / supply;
                acc += deltaAcc;
            } else if (weekReady && net > 0 && openPts > 0 && userEpoch == epoch) {
                uint256 livePts = userPts;
                if (block.timestamp > last) livePts += userBal * (block.timestamp - last);
                if (livePts > 0) stored += (livePts * net) / openPts;
            }
        }
        uint256 mark = hypeTipEpochPlusOne[user];
        if (mark != 0) {
            uint256 e = mark - 1;
            uint256 pot = hypeEpochPot[e];
            if (e == addEpoch) pot += addNet;
            uint256 pts = hypeTipPts[user];
            uint256 tot = hypeEpochPoints[e];
            if (pts > 0 && tot > 0 && pot > 0) {
                uint256 gross = (pts * pot) / tot;
                uint256 paid = hypeTipPaid[user];
                if (gross > paid) stored += gross - paid;
            }
        }
        uint256 n;
        while (userEpoch < epoch && n < HYPE_CREDIT_BATCH) {
            uint256 closeT = hypeEpochClosedAt[userEpoch];
            if (closeT > last) userPts += userBal * (closeT - last);
            uint256 tot = hypeEpochPoints[userEpoch];
            uint256 pot = hypeEpochPot[userEpoch];
            if (userEpoch == addEpoch) pot += addNet;
            if (userPts > 0 && tot > 0 && pot > 0) stored += (userPts * pot) / tot;
            last = closeT;
            userPts = 0;
            userEpoch += 1;
            unchecked {
                ++n;
            }
        }
        snapAcc = (userBal * acc) / 1e18;
        snapPend = snapAcc > hypeRewardDebt[user] ? snapAcc - hypeRewardDebt[user] : 0;
    }
}
