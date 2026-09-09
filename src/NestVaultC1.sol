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
 * @title NestVaultC1
 * @notice C1-style Nest claim vault: deposit NEST -> lock veNEST -> mint transferable hNEST.
 *
 * Product policy:
 * - User redemption is permanently disabled. hNEST is the transferable claim and exits via secondary market.
 * - No user withdrawal queue, idle redemption buffer, or keeper-driven liquidity detachment exists.
 * - 100% of every deposit is locked into veNEST.
 * - veNEST NFT detach / transfer / withdrawal are owner-only migration/emergency paths.
 */
contract NestVaultC1 is Ownable2Step, ReentrancyGuard, Pausable, IERC721Receiver, INestVaultHype {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LOCK_DURATION = 26 weeks;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_FEE_BPS = 500;

    IERC20 public immutable nestToken;
    IVotingEscrow public immutable veNEST;
    IERC20 public immutable hypeToken;
    HNest public immutable hNest;

    IHevAdapter public hevAdapter;
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

    uint256 public totalHypeDistributed;
    mapping(address => uint256) public hypeRewardDebt;
    uint256 public accHypePerShare;
    uint256 public lastHypeBalance;
    mapping(uint256 => uint256) public bookedLockedShare;

    event Deposited(address indexed user, uint256 nestAmount, uint256 hNestMinted, uint256 indexed tokenId);
    event DepositGateUpdated(address indexed oldGate, address indexed newGate);
    event DepositsEnabledUpdated(bool enabled);
    event DepositCapUpdated(uint256 oldCap, uint256 newCap);
    event KeeperUpdated(address oldKeeper, address newKeeper);
    event GuardianUpdated(address oldGuardian, address newGuardian);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event HevAdapterUpdated(address oldAdapter, address newAdapter);
    event ResidualHypeClaimed(address indexed user, uint256 amount);
    event YieldBooked(uint256 addedNest, uint256 feeAssets, uint256 feeShares);
    event NestCompoundRecorded(uint256 addedNest);
    event VeNFTDetachedForAdmin(uint256 indexed tokenId);
    event VeNFTTransferredForAdmin(uint256 indexed tokenId, address indexed recipient);
    event VeNFTWithdrawnForAdmin(uint256 indexed tokenId, address indexed recipient, uint256 amount);

    error ZeroAmount();
    error ZeroAddress();
    error OnlyHNest();
    error NotKeeper();
    error NotGuardianOrOwner();
    error DepositCapExceeded();
    error DepositsDisabled();
    error OnlyDepositGate();
    error ZeroShares();
    error FeeTooHigh();
    error InvalidHNest();
    error HevAdapterNotSet();
    error HevAdapterChangeWhileLive();
    error NotVaultOwnedNFT();
    error NFTStillAttached();
    error RedemptionDisabled();

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
        address _hNest
    ) Ownable(msg.sender) {
        if (
            _nestToken == address(0) || _veNEST == address(0) || _hypeToken == address(0)
                || _feeRecipient == address(0) || _keeper == address(0)
        ) revert ZeroAddress();

        nestToken = IERC20(_nestToken);
        veNEST = IVotingEscrow(_veNEST);
        hypeToken = IERC20(_hypeToken);
        hevAdapter = IHevAdapter(_hevAdapter);
        feeRecipient = _feeRecipient;
        keeper = _keeper;
        guardian = _guardian;
        depositCap = _depositCap;

        if (_hNest == address(0)) {
            hNest = new HNest(address(this));
        } else {
            hNest = HNest(_hNest);
            if (hNest.vault() != address(this)) revert InvalidHNest();
        }
        nestToken.forceApprove(address(veNEST), type(uint256).max);
    }

    function deposit(uint256 nestAmount) external nonReentrant whenNotPaused {
        if (!depositsEnabled) revert DepositsDisabled();
        if (depositGate != address(0) && msg.sender != depositGate) revert OnlyDepositGate();
        if (nestAmount == 0) revert ZeroAmount();
        if (depositCap > 0 && totalNestLocked + nestAmount > depositCap) revert DepositCapExceeded();

        _updateHypeAccumulator();
        uint256 totalSupply = hNest.totalSupply();
        uint256 hNestToMint = totalSupply == 0 || totalNestLocked == 0
            ? nestAmount
            : (nestAmount * totalSupply) / totalNestLocked;
        if (hNestToMint == 0) revert ZeroShares();

        nestToken.safeTransferFrom(msg.sender, address(this), nestAmount);
        uint256 tokenId = veNEST.createLockFor(
            nestAmount,
            MAX_LOCK_DURATION,
            address(this),
            false,
            false,
            HyperEVMAddresses.HEV_MANAGED_TOKEN_ID
        );
        veNFTIds.push(tokenId);
        nestPrincipal[tokenId] = nestAmount;
        totalNestLocked += nestAmount;

        if (address(hevAdapter) != address(0)) {
            veNEST.approve(address(hevAdapter), tokenId);
            hevAdapter.depositVeNFT(tokenId);
            inHev[tokenId] = true;
        }

        hNest.mint(msg.sender, hNestToMint);
        hypeRewardDebt[msg.sender] = (hNest.balanceOf(msg.sender) * accHypePerShare) / 1e18;
        emit Deposited(msg.sender, nestAmount, hNestToMint, tokenId);
    }

    /// @notice C1 has no native redeem. hNEST exits only through transfer / secondary market.
    function requestWithdraw(uint256) external pure {
        revert RedemptionDisabled();
    }

    function settleResidualHype(address user) external override {
        if (msg.sender != address(hNest)) revert OnlyHNest();
        _claimResidualHypeInternal(user);
    }

    function updateDebt(address user) external override {
        if (msg.sender != address(hNest)) revert OnlyHNest();
        hypeRewardDebt[user] = (hNest.balanceOf(user) * accHypePerShare) / 1e18;
    }

    function claimResidualHype() external nonReentrant {
        _claimResidualHypeInternal(msg.sender);
    }

    function harvest() external onlyKeeper nonReentrant {
        if (address(hevAdapter) == address(0) || veNFTIds.length == 0) return;
        uint256 beforeBal = hypeToken.balanceOf(address(this));
        hevAdapter.sweepResidualHype(veNFTIds, address(this));
        uint256 hypeGained = hypeToken.balanceOf(address(this)) - beforeBal;
        if (hypeGained == 0) return;
        uint256 fee = (hypeGained * feeBps) / BASIS_POINTS;
        if (fee > 0) hypeToken.safeTransfer(feeRecipient, fee);
        uint256 net = hypeGained - fee;
        uint256 supply = hNest.totalSupply();
        if (supply > 0 && net > 0) accHypePerShare += (net * 1e18) / supply;
        lastHypeBalance = hypeToken.balanceOf(address(this));
    }

    function bookVerifiedYield() external onlyKeeper nonReentrant {
        if (address(hevAdapter) == address(0)) revert HevAdapterNotSet();
        uint256 y;
        uint256 n = veNFTIds.length;
        for (uint256 i; i < n; ++i) {
            uint256 tokenId = veNFTIds[i];
            if (!inHev[tokenId]) continue;
            uint256 pending = hevAdapter.pendingLockedNestShare(tokenId);
            uint256 booked = bookedLockedShare[tokenId];
            if (pending > booked) {
                y += pending - booked;
                bookedLockedShare[tokenId] = pending;
            }
        }
        if (y == 0) revert ZeroShares();
        uint256 feeAssets = (y * feeBps) / BASIS_POINTS;
        uint256 supply = hNest.totalSupply();
        totalNestLocked += y;
        uint256 feeShares;
        if (feeAssets > 0 && supply > 0 && totalNestLocked > feeAssets) {
            feeShares = (feeAssets * supply) / (totalNestLocked - feeAssets);
            if (feeShares > 0) {
                hNest.mint(feeRecipient, feeShares);
                hypeRewardDebt[feeRecipient] = (hNest.balanceOf(feeRecipient) * accHypePerShare) / 1e18;
            }
        }
        emit YieldBooked(y, feeAssets, feeShares);
        emit NestCompoundRecorded(y);
    }

    // Owner-only migration/emergency custody. Moving backing can change hNEST collateralization and is not a user exit.
    function ownerDetachVeNFT(uint256 tokenId) external onlyOwner nonReentrant {
        _requireVaultOwned(tokenId);
        if (!inHev[tokenId]) return;
        if (address(hevAdapter) == address(0)) revert HevAdapterNotSet();
        hevAdapter.withdrawVeNFT(tokenId);
        inHev[tokenId] = false;
        emit VeNFTDetachedForAdmin(tokenId);
    }

    function ownerTransferVeNFT(uint256 tokenId, address recipient) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        _requireVaultOwned(tokenId);
        if (inHev[tokenId]) revert NFTStillAttached();
        veNEST.transferFrom(address(this), recipient, tokenId);
        emit VeNFTTransferredForAdmin(tokenId, recipient);
    }

    function ownerWithdrawVeNFT(uint256 tokenId, address recipient)
        external
        onlyOwner
        nonReentrant
        returns (uint256 amount)
    {
        if (recipient == address(0)) revert ZeroAddress();
        _requireVaultOwned(tokenId);
        if (inHev[tokenId]) revert NFTStillAttached();
        amount = veNEST.balanceOfNFT(tokenId);
        veNEST.withdraw(tokenId);
        _removeTrackedNFT(tokenId);
        if (amount > totalNestLocked) totalNestLocked = 0;
        else totalNestLocked -= amount;
        nestToken.safeTransfer(recipient, amount);
        emit VeNFTWithdrawnForAdmin(tokenId, recipient, amount);
    }

    function _requireVaultOwned(uint256 tokenId) internal view {
        if (veNEST.ownerOf(tokenId) != address(this)) revert NotVaultOwnedNFT();
    }

    function _removeTrackedNFT(uint256 tokenId) internal {
        uint256 len = veNFTIds.length;
        for (uint256 i; i < len; ++i) {
            if (veNFTIds[i] == tokenId) {
                uint256 last = len - 1;
                if (i != last) veNFTIds[i] = veNFTIds[last];
                veNFTIds.pop();
                delete inHev[tokenId];
                delete nestPrincipal[tokenId];
                delete bookedLockedShare[tokenId];
                return;
            }
        }
    }

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
        emit FeeRecipientUpdated(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    function setDepositCap(uint256 _depositCap) external onlyOwner {
        emit DepositCapUpdated(depositCap, _depositCap);
        depositCap = _depositCap;
    }

    function setDepositGate(address _gate) external onlyOwner {
        emit DepositGateUpdated(depositGate, _gate);
        depositGate = _gate;
    }

    function setHevAdapter(address _hevAdapter) external onlyOwner {
        if (_hevAdapter == address(0)) revert ZeroAddress();
        if (totalNestLocked != 0) revert HevAdapterChangeWhileLive();
        emit HevAdapterUpdated(address(hevAdapter), _hevAdapter);
        hevAdapter = IHevAdapter(_hevAdapter);
    }

    function setDepositsEnabled(bool enabled) external onlyOwner {
        depositsEnabled = enabled;
        emit DepositsEnabledUpdated(enabled);
    }

    function pause() external onlyGuardianOrOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setGuardian(address _guardian) external onlyOwner {
        emit GuardianUpdated(guardian, _guardian);
        guardian = _guardian;
    }

    function sharePrice() external view returns (uint256) {
        uint256 totalSupply = hNest.totalSupply();
        if (totalSupply == 0) return 1e18;
        return (totalNestLocked * 1e18) / totalSupply;
    }

    function pendingVerifiedYield() external view returns (uint256 y) {
        if (address(hevAdapter) == address(0)) return 0;
        uint256 n = veNFTIds.length;
        for (uint256 i; i < n; ++i) {
            uint256 tokenId = veNFTIds[i];
            if (!inHev[tokenId]) continue;
            uint256 pending = hevAdapter.pendingLockedNestShare(tokenId);
            uint256 booked = bookedLockedShare[tokenId];
            if (pending > booked) y += pending - booked;
        }
    }

    function totalVeNFTs() external view returns (uint256) {
        return veNFTIds.length;
    }

    function getVeNFTId(uint256 index) external view returns (uint256) {
        return veNFTIds[index];
    }

    function _updateHypeAccumulator() internal {
        uint256 currentHypeBalance = hypeToken.balanceOf(address(this));
        uint256 supply = hNest.totalSupply();
        if (currentHypeBalance > lastHypeBalance && supply > 0) {
            accHypePerShare += ((currentHypeBalance - lastHypeBalance) * 1e18) / supply;
            lastHypeBalance = currentHypeBalance;
        }
    }

    function _claimResidualHypeInternal(address user) internal {
        _updateHypeAccumulator();
        uint256 balance = hNest.balanceOf(user);
        uint256 pending = (balance * accHypePerShare) / 1e18 - hypeRewardDebt[user];
        if (pending > 0) {
            hypeToken.safeTransfer(user, pending);
            totalHypeDistributed += pending;
            lastHypeBalance = hypeToken.balanceOf(address(this));
            emit ResidualHypeClaimed(user, pending);
        }
        hypeRewardDebt[user] = (balance * accHypePerShare) / 1e18;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
