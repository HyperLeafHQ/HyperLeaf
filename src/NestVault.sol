// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {HNest} from "./HNest.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IHevAdapter} from "./interfaces/IHevAdapter.sol";
import {INestVaultHype} from "./interfaces/INestVaultHype.sol";
import {HyperEVMAddresses} from "./config/HyperEVMAddresses.sol";

/**
 * @title NestVault
 * @notice hNEST core vault: deposit NEST → lock veNEST → deposit HEV → mint hNEST.
 *
 * Yield / accounting:
 * 1) veNEST auto-compound into locked positions (share price) — recording via recordCompound is DISABLED (HL-002)
 * 2) Residual ERC20 HYPE swept from HevAdapter (usually 0) distributed MasterChef-style — NOT liquid Nest HYPE rewards
 *
 * HEV mode: harvest does NOT vote or increaseUnlockTime (HEV auto-votes).
 *
 * Withdraw liquidity (see docs/WITHDRAW_WINDOWS.md):
 * - Idle NEST buffer (deposit skim + optional keeper top-up) serves the queue
 * - Do NOT dettach on every requestWithdraw (live onDettach resets lock to ~now+26w)
 * - Attached getNftState amount/end are zero — use nestPrincipal / unlockEligibleAt
 * - dettachForLiquidity caps principal to queue gap + owner buffer bps (HL-003)
 */
contract NestVault is Ownable2Step, ReentrancyGuard, Pausable, IERC721Receiver, INestVaultHype {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LOCK_DURATION = 26 weeks;
    /// @notice Matches HEV.detachmentLockDuration() on HyperEVM (345600).
    uint256 public constant DETACHMENT_LOCK_DURATION = 4 days;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_FEE_BPS = 500;
    /// @notice Cap on deposit skim into idle buffer (safety: keep most capital productive).
    uint256 public constant MAX_IDLE_DEPOSIT_BPS = 2_000;
    /// @notice Cap on optional overshoot when dettaching for liquidity (gap + buffer).
    uint256 public constant MAX_DETTACH_BUFFER_BPS = 5_000;

    IERC20 public immutable nestToken;
    IVotingEscrow public immutable veNEST;
    IERC20 public immutable hypeToken;
    HNest public immutable hNest;

    IHevAdapter public hevAdapter;
    address public keeper;
    /// @notice Can pause (with owner). Cannot unpause. address(0) disables guardian.
    address public guardian;
    address public feeRecipient;
    uint256 public feeBps = 100;
    uint256 public depositCap; // 0 = uncapped

    /// @notice Absolute idle NEST floor; fulfillments only spend balance above this.
    uint256 public minIdleNest;
    /// @notice Portion of each deposit kept as idle NEST (not locked into veNFT).
    uint256 public idleDepositBps;
    /// @notice Extra bps of queue gap allowed when selecting dettach principal (owner-set).
    uint256 public dettachBufferBps;
    /// @notice Deposits closed until owner enables (HL-007). Default false.
    bool public depositsEnabled;

    uint256[] public veNFTIds;
    mapping(uint256 => bool) public inHev;
    /// @notice Vault-tracked NEST principal per veNFT (ignore attached getNftState.amount).
    mapping(uint256 => uint256) public nestPrincipal;
    /// @notice When vault recorded attach (4d dettach gate).
    mapping(uint256 => uint256) public attachedAt;
    /// @notice Earliest time vault will call veNEST.withdraw after dettach (now+26w on dettach).
    mapping(uint256 => uint256) public unlockEligibleAt;
    uint256 public totalNestLocked;

    struct WithdrawRequest {
        address user;
        uint256 nestAmount;
        uint256 requestTime;
        bool fulfilled;
    }

    WithdrawRequest[] public withdrawQueue;
    uint256 public withdrawQueueHead;

    uint256 public totalHypeDistributed;
    mapping(address => uint256) public hypeRewardDebt;
    uint256 public accHypePerShare; // 1e18 precision
    uint256 public lastHypeBalance;

    event Deposited(address indexed user, uint256 nestAmount, uint256 hNestMinted);
    event WithdrawRequested(address indexed user, uint256 hNestBurned, uint256 nestAmount, uint256 queueIndex);
    event WithdrawFulfilled(address indexed user, uint256 nestAmount, uint256 queueIndex);
    event HarvestExecuted(uint256 nestCompounded, uint256 hypeClaimed, uint256 feesTaken);
    event KeeperUpdated(address oldKeeper, address newKeeper);
    event GuardianUpdated(address oldGuardian, address newGuardian);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event DepositCapUpdated(uint256 oldCap, uint256 newCap);
    event HevAdapterUpdated(address oldAdapter, address newAdapter);
    event ResidualHypeClaimed(address indexed user, uint256 amount);
    event DepositsEnabledUpdated(bool enabled);
    event DettachBufferBpsUpdated(uint256 oldBps, uint256 newBps);
    event NestCompoundRecorded(uint256 addedNest);
    event MinIdleNestUpdated(uint256 oldMin, uint256 newMin);
    event IdleDepositBpsUpdated(uint256 oldBps, uint256 newBps);
    event IdleToppedUp(address indexed from, uint256 amount);
    event DettachForLiquidity(uint256 indexed tokenId, uint256 unlockEligibleAt);
    event NestUnlocked(uint256 indexed tokenId, uint256 principal);

    error ZeroAmount();
    error ZeroAddress();
    error NotKeeper();
    error NotGuardianOrOwner();
    error InsufficientHNest();
    error ZeroShares();
    error DepositCapExceeded();
    error FeeTooHigh();
    error OnlyHNest();
    error InvalidHNest();
    error IdleBufferShortfall(uint256 available, uint256 required);
    error IdleDepositBpsTooHigh();
    error DettachBufferBpsTooHigh();
    error DettachTooEarly(uint256 tokenId, uint256 availableAt);
    error NotInHev(uint256 tokenId);
    error UnknownNft(uint256 tokenId);
    error CompoundDisabled();
    error DepositsDisabled();
    error HevAdapterNotSet();

    modifier onlyKeeper() {
        if (msg.sender != keeper && msg.sender != owner()) revert NotKeeper();
        _;
    }

    modifier onlyGuardianOrOwner() {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardianOrOwner();
        _;
    }

    /// @param _hNest Pre-deployed HNest whose vault() must equal this contract, or address(0)
    ///               to deploy HNest in-constructor (anvil/tests only — HyperEVM 3M block gas
    ///               limit cannot fit NestVault+HNest create in one tx).
    constructor(
        address _nestToken,
        address _veNEST,
        address _hypeToken,
        address _hevAdapter,
        address _feeRecipient,
        address _keeper,
        address _guardian,
        uint256 _depositCap,
        address _hNest
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
        guardian = _guardian; // address(0) = no guardian until setGuardian
        depositCap = _depositCap;

        if (_hNest == address(0)) {
            hNest = new HNest(address(this));
        } else {
            hNest = HNest(_hNest);
            if (hNest.vault() != address(this)) revert InvalidHNest();
        }
        nestToken.forceApprove(address(veNEST), type(uint256).max);
    }

    // ============ User ============

    function deposit(uint256 nestAmount) external nonReentrant whenNotPaused {
        if (!depositsEnabled) revert DepositsDisabled();
        if (nestAmount == 0) revert ZeroAmount();
        if (depositCap > 0 && totalNestLocked + nestAmount > depositCap) revert DepositCapExceeded();

        _updateHypeAccumulator();

        uint256 hNestToMint;
        uint256 totalSupply = hNest.totalSupply();
        if (totalSupply == 0 || totalNestLocked == 0) {
            hNestToMint = nestAmount;
        } else {
            hNestToMint = (nestAmount * totalSupply) / totalNestLocked;
        }
        if (hNestToMint == 0) revert ZeroShares();

        nestToken.safeTransferFrom(msg.sender, address(this), nestAmount);

        uint256 idlePart = (nestAmount * idleDepositBps) / BASIS_POINTS;
        uint256 lockPart = nestAmount - idlePart;

        if (lockPart > 0) {
            // Nest veNEST: createLock(value,duration) is MISSING on mainnet.
            // createLockFor(..., managedTokenIdForAttach_=HEV) locks + attaches atomically.
            // Flags: shouldBoosted_=false (boost surface not productized here);
            //        withPermanentLock_=false (preserve unlock/withdraw queue path).
            uint256 tokenId = veNEST.createLockFor(
                lockPart, MAX_LOCK_DURATION, address(this), false, false, HyperEVMAddresses.HEV_MANAGED_TOKEN_ID
            );
            veNFTIds.push(tokenId);
            nestPrincipal[tokenId] = lockPart;
            attachedAt[tokenId] = block.timestamp;
            unlockEligibleAt[tokenId] = 0;

            // Adapter records deposit; attach is idempotent if createLockFor already attached.
            if (address(hevAdapter) != address(0)) {
                veNEST.approve(address(hevAdapter), tokenId);
                hevAdapter.depositVeNFT(tokenId);
                inHev[tokenId] = true;
            }
        }

        totalNestLocked += nestAmount;

        hNest.mint(msg.sender, hNestToMint);
        hypeRewardDebt[msg.sender] = (hNest.balanceOf(msg.sender) * accHypePerShare) / 1e18;

        emit Deposited(msg.sender, nestAmount, hNestToMint);
    }

    /**
     * @notice Queue a redeem. Burns hNEST immediately. Does NOT dettach veNFTs
     *         (live onDettach resets lock end to ~now+26w — see WITHDRAW_WINDOWS.md).
     */
    function requestWithdraw(uint256 hNestAmount) external nonReentrant whenNotPaused {
        if (hNestAmount == 0) revert ZeroAmount();
        if (hNest.balanceOf(msg.sender) < hNestAmount) revert InsufficientHNest();

        _claimResidualHypeInternal(msg.sender);

        uint256 totalSupply = hNest.totalSupply();
        uint256 nestAmount = (hNestAmount * totalNestLocked) / totalSupply;

        hNest.burn(msg.sender, hNestAmount);

        uint256 queueIndex = withdrawQueue.length;
        withdrawQueue.push(
            WithdrawRequest({user: msg.sender, nestAmount: nestAmount, requestTime: block.timestamp, fulfilled: false})
        );

        totalNestLocked -= nestAmount;
        hypeRewardDebt[msg.sender] = (hNest.balanceOf(msg.sender) * accHypePerShare) / 1e18;

        emit WithdrawRequested(msg.sender, hNestAmount, nestAmount, queueIndex);
    }

    /**
     * @notice Claim residual HYPE ERC20 accrued to the caller via MasterChef debt.
     * @dev Not Nest liquid HYPE / MEGAHYPE rewards — only tokens swept into the vault.
     */
    function claimResidualHype() external nonReentrant {
        _claimResidualHypeInternal(msg.sender);
    }

    // ============ HNest transfer hooks ============

    function settleResidualHype(address user) external override {
        if (msg.sender != address(hNest)) revert OnlyHNest();
        _claimResidualHypeInternal(user);
    }

    function updateDebt(address user) external override {
        if (msg.sender != address(hNest)) revert OnlyHNest();
        hypeRewardDebt[user] = (hNest.balanceOf(user) * accHypePerShare) / 1e18;
    }

    // ============ Keeper (HEV mode) ============

    /**
     * @notice Weekly keeper job: sweep residual HYPE from adapter (usually 0), update MasterChef acc,
     *         process withdraw queue. Does NOT vote or increaseUnlockTime (HEV auto-votes).
     * @dev Does not dettach NFTs. Does not revert on idle shortfall (queue waits).
     *      Does not invent Nest liquid HYPE rewards.
     */
    function harvest() external onlyKeeper nonReentrant {
        uint256 nestCompounded = 0;
        uint256 hypeClaimedNet = 0;
        uint256 feesTaken = 0;

        if (address(hevAdapter) != address(0) && veNFTIds.length > 0) {
            uint256 beforeBal = hypeToken.balanceOf(address(this));
            hevAdapter.sweepResidualHype(veNFTIds, address(this));
            uint256 hypeGained = hypeToken.balanceOf(address(this)) - beforeBal;

            if (hypeGained > 0) {
                feesTaken = (hypeGained * feeBps) / BASIS_POINTS;
                if (feesTaken > 0) {
                    hypeToken.safeTransfer(feeRecipient, feesTaken);
                }
                hypeClaimedNet = hypeGained - feesTaken;

                // Credit net HYPE into accumulator (exclude fee already transferred out)
                uint256 supply = hNest.totalSupply();
                if (supply > 0 && hypeClaimedNet > 0) {
                    // lastHypeBalance should reflect pre-claim vault balance of distributable HYPE
                    // After fee transfer, vault holds beforeBal + hypeClaimedNet
                    uint256 distributableBefore = lastHypeBalance;
                    // Sync: treat newly arrived net HYPE as reward
                    accHypePerShare += (hypeClaimedNet * 1e18) / supply;
                    lastHypeBalance = hypeToken.balanceOf(address(this));
                    // silence unused
                    distributableBefore;
                } else {
                    lastHypeBalance = hypeToken.balanceOf(address(this));
                }
            }
        }

        _processWithdrawQueue();
        emit HarvestExecuted(nestCompounded, hypeClaimedNet, feesTaken);
    }

    /**
     * @notice Process unlock-eligible NFTs + fulfill queue from idle surplus.
     * @dev Soft: does not revert on shortfall. Use `processWithdrawQueueOrRevert` to surface shortfall.
     */
    function processWithdrawQueue() external onlyKeeper nonReentrant {
        _processWithdrawQueue();
    }

    /**
     * @notice Same as processWithdrawQueue, but reverts IdleBufferShortfall when the
     *         queue head is payable from raw balance yet blocked only by minIdleNest.
     */
    function processWithdrawQueueOrRevert() external onlyKeeper nonReentrant {
        _processWithdrawQueue();
        if (withdrawQueueHead >= withdrawQueue.length) return;
        WithdrawRequest storage head = withdrawQueue[withdrawQueueHead];
        if (head.fulfilled) return;
        uint256 bal = nestToken.balanceOf(address(this));
        uint256 available = _availableIdle(bal);
        if (bal >= head.nestAmount && available < head.nestAmount) {
            revert IdleBufferShortfall(available, head.nestAmount);
        }
    }

    /**
     * @notice Batch dettach NFTs only when queue needs liquidity. Starts ~26w unlock clock.
     * @dev Requires DETACHMENT_LOCK_DURATION (4d) since attach. Does not call veNEST.withdraw.
     *      Caps cumulative nestPrincipal dettached to queue gap + dettachBufferBps (HL-003).
     *      Requires non-zero hevAdapter and successful withdrawVeNFT before clearing inHev (HL-008).
     */
    function dettachForLiquidity(uint256[] calldata tokenIds) external onlyKeeper nonReentrant {
        uint256 pending = _pendingWithdrawNest();
        uint256 available = availableIdleNest();
        if (pending <= available) {
            // No need to reset 26w clocks if idle already covers the queue
            return;
        }
        if (address(hevAdapter) == address(0)) revert HevAdapterNotSet();

        uint256 gap = pending - available;
        uint256 cap = gap + (gap * dettachBufferBps) / BASIS_POINTS;
        uint256 dettachedPrincipal;

        for (uint256 i = 0; i < tokenIds.length; ++i) {
            if (dettachedPrincipal >= cap) break;

            uint256 tokenId = tokenIds[i];
            if (nestPrincipal[tokenId] == 0) revert UnknownNft(tokenId);
            if (!inHev[tokenId]) revert NotInHev(tokenId);

            uint256 availableAt = attachedAt[tokenId] + DETACHMENT_LOCK_DURATION;
            if (block.timestamp < availableAt) revert DettachTooEarly(tokenId, availableAt);

            // State changes only after successful adapter withdraw (HL-008).
            hevAdapter.withdrawVeNFT(tokenId);
            inHev[tokenId] = false;
            // Mirror live onDettach: lock end ≈ now+26w. Do not trust getNftState while attached.
            unlockEligibleAt[tokenId] = block.timestamp + MAX_LOCK_DURATION;
            dettachedPrincipal += nestPrincipal[tokenId];
            emit DettachForLiquidity(tokenId, unlockEligibleAt[tokenId]);
        }
    }

    /**
     * @notice Keeper/owner tops up idle NEST without minting hNEST (buffer refill).
     * @dev Does not change totalNestLocked / share price accounting.
     */
    function topUpIdle(uint256 amount) external onlyKeeper nonReentrant {
        if (amount == 0) revert ZeroAmount();
        nestToken.safeTransferFrom(msg.sender, address(this), amount);
        emit IdleToppedUp(msg.sender, amount);
    }

    /**
     * @notice DISABLED (HL-002): unbacked compound must not raise totalNestLocked.
     * @dev Always reverts CompoundDisabled. Kept as stub so ABI/callers fail closed.
     */
    function recordCompound(uint256) external pure {
        revert CompoundDisabled();
    }

    // ============ Internal ============

    function _availableIdle(uint256 bal) internal view returns (uint256) {
        if (bal <= minIdleNest) return 0;
        return bal - minIdleNest;
    }

    function _pendingWithdrawNest() internal view returns (uint256 pending) {
        uint256 len = withdrawQueue.length;
        for (uint256 i = withdrawQueueHead; i < len; ++i) {
            if (!withdrawQueue[i].fulfilled) {
                pending += withdrawQueue[i].nestAmount;
            }
        }
    }

    function _processWithdrawQueue() internal {
        // 1) Unlock vault-eligible detached NFTs (ignore attached amount/end — use unlockEligibleAt).
        uint256 nftCount = veNFTIds.length;
        for (uint256 i = 0; i < nftCount;) {
            uint256 tokenId = veNFTIds[i];

            // Still in HEV / attached path — never read amount/end for readiness.
            if (inHev[tokenId]) {
                unchecked {
                    ++i;
                }
                continue;
            }

            uint256 eligibleAt = unlockEligibleAt[tokenId];
            if (eligibleAt == 0 || block.timestamp < eligibleAt) {
                unchecked {
                    ++i;
                }
                continue;
            }

            IVotingEscrow.TokenState memory state = veNEST.getNftState(tokenId);
            // Only use isAttached; amount/end were zero while attached and end was reset on dettach.
            if (state.isAttached) {
                unchecked {
                    ++i;
                }
                continue;
            }

            uint256 principal = nestPrincipal[tokenId];
            veNEST.withdraw(tokenId);
            delete nestPrincipal[tokenId];
            delete unlockEligibleAt[tokenId];
            delete attachedAt[tokenId];
            emit NestUnlocked(tokenId, principal);
            _removeNFTFromArray(i);
            unchecked {
                nftCount--;
            }
        }

        // 2) Fulfill queue from idle surplus only (never spend below minIdleNest).
        uint256 availableNest = _availableIdle(nestToken.balanceOf(address(this)));
        uint256 queueLength = withdrawQueue.length;
        for (uint256 i = withdrawQueueHead; i < queueLength; ++i) {
            WithdrawRequest storage request = withdrawQueue[i];
            if (request.fulfilled) continue;

            if (availableNest >= request.nestAmount) {
                availableNest -= request.nestAmount;
                request.fulfilled = true;
                withdrawQueueHead = i + 1;
                nestToken.safeTransfer(request.user, request.nestAmount);
                emit WithdrawFulfilled(request.user, request.nestAmount, i);
            } else {
                break;
            }
        }
    }

    function _updateHypeAccumulator() internal {
        uint256 currentHypeBalance = hypeToken.balanceOf(address(this));
        uint256 totalSupply = hNest.totalSupply();
        if (currentHypeBalance > lastHypeBalance && totalSupply > 0) {
            uint256 newHype = currentHypeBalance - lastHypeBalance;
            accHypePerShare += (newHype * 1e18) / totalSupply;
            lastHypeBalance = currentHypeBalance;
        }
    }

    function _claimResidualHypeInternal(address user) internal {
        _updateHypeAccumulator();
        uint256 userBalance = hNest.balanceOf(user);
        uint256 pending = (userBalance * accHypePerShare) / 1e18 - hypeRewardDebt[user];

        if (pending > 0) {
            hypeToken.safeTransfer(user, pending);
            totalHypeDistributed += pending;
            lastHypeBalance = hypeToken.balanceOf(address(this));
            emit ResidualHypeClaimed(user, pending);
        }
        hypeRewardDebt[user] = (userBalance * accHypePerShare) / 1e18;
    }

    function _removeNFTFromArray(uint256 index) internal {
        uint256 lastIndex = veNFTIds.length - 1;
        if (index != lastIndex) {
            veNFTIds[index] = veNFTIds[lastIndex];
        }
        veNFTIds.pop();
    }

    // ============ Views ============

    function sharePrice() external view returns (uint256) {
        uint256 totalSupply = hNest.totalSupply();
        if (totalSupply == 0) return 1e18;
        return (totalNestLocked * 1e18) / totalSupply;
    }

    /**
     * @notice Pending residual HYPE ERC20 for `user` (MasterChef debt), not Nest locked NEST share.
     */
    function pendingResidualHype(address user) external view returns (uint256) {
        uint256 currentAcc = accHypePerShare;
        uint256 currentBalance = hypeToken.balanceOf(address(this));
        if (currentBalance > lastHypeBalance && hNest.totalSupply() > 0) {
            uint256 newHype = currentBalance - lastHypeBalance;
            currentAcc += (newHype * 1e18) / hNest.totalSupply();
        }
        return (hNest.balanceOf(user) * currentAcc) / 1e18 - hypeRewardDebt[user];
    }

    function withdrawQueueStatus()
        external
        view
        returns (uint256 totalRequests, uint256 processedRequests, uint256 pendingRequests)
    {
        totalRequests = withdrawQueue.length;
        processedRequests = withdrawQueueHead;
        pendingRequests = totalRequests - processedRequests;
    }

    /// @notice Idle NEST spendable for queue fulfillments (balance minus minIdleNest).
    function availableIdleNest() public view returns (uint256) {
        return _availableIdle(nestToken.balanceOf(address(this)));
    }

    /// @notice Sum of unfulfilled queue nest amounts.
    function pendingWithdrawNest() external view returns (uint256) {
        return _pendingWithdrawNest();
    }

    function totalVeNFTs() external view returns (uint256) {
        return veNFTIds.length;
    }

    function getVeNFTId(uint256 index) external view returns (uint256) {
        return veNFTIds[index];
    }

    // ============ Admin ============

    function setKeeper(address _keeper) external onlyOwner {
        if (_keeper == address(0)) revert ZeroAddress();
        emit KeeperUpdated(keeper, _keeper);
        keeper = _keeper;
    }

    function setFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        emit FeeUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
    }

    function setDepositCap(uint256 _depositCap) external onlyOwner {
        emit DepositCapUpdated(depositCap, _depositCap);
        depositCap = _depositCap;
    }

    function setHevAdapter(address _hevAdapter) external onlyOwner {
        if (_hevAdapter == address(0)) revert ZeroAddress();
        emit HevAdapterUpdated(address(hevAdapter), _hevAdapter);
        hevAdapter = IHevAdapter(_hevAdapter);
    }

    /// @notice Absolute idle floor. Reverts if current balance cannot cover the new floor.
    function setMinIdleNest(uint256 _minIdleNest) external onlyOwner {
        uint256 bal = nestToken.balanceOf(address(this));
        if (bal < _minIdleNest) revert IdleBufferShortfall(bal, _minIdleNest);
        emit MinIdleNestUpdated(minIdleNest, _minIdleNest);
        minIdleNest = _minIdleNest;
    }

    /// @notice Deposit skim into idle buffer (0–MAX_IDLE_DEPOSIT_BPS).
    function setIdleDepositBps(uint256 _idleDepositBps) external onlyOwner {
        if (_idleDepositBps > MAX_IDLE_DEPOSIT_BPS) revert IdleDepositBpsTooHigh();
        emit IdleDepositBpsUpdated(idleDepositBps, _idleDepositBps);
        idleDepositBps = _idleDepositBps;
    }

    /// @notice Pause deposits and withdraw requests. Guardian or owner. Keeper cannot.
    function pause() external onlyGuardianOrOwner {
        _pause();
    }

    /// @notice Unpause. Owner only — guardian/keeper cannot unpause (anti-hijack).
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Extra bps of queue gap allowed as dettach principal cap (0–MAX_DETTACH_BUFFER_BPS).
    function setDettachBufferBps(uint256 _dettachBufferBps) external onlyOwner {
        if (_dettachBufferBps > MAX_DETTACH_BUFFER_BPS) revert DettachBufferBpsTooHigh();
        emit DettachBufferBpsUpdated(dettachBufferBps, _dettachBufferBps);
        dettachBufferBps = _dettachBufferBps;
    }

    /// @notice Open/close deposits. Default false until owner enables after checklist (HL-007).
    function setDepositsEnabled(bool enabled) external onlyOwner {
        depositsEnabled = enabled;
        emit DepositsEnabledUpdated(enabled);
    }

    /// @notice Set guardian. Owner only. address(0) disables the guardian role.
    /// @dev Guardian may pause only — cannot unpause or change idle params.
    function setGuardian(address _guardian) external onlyOwner {
        emit GuardianUpdated(guardian, _guardian);
        guardian = _guardian;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
