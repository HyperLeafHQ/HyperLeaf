// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LeafOApp} from "./LeafOApp.sol";
import {LeafYieldFee} from "./LeafYieldFee.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";

/// @title LeafOFTAdapter
/// @notice Source-chain lockbox for an existing ERC20 (e.g. sKAITO / xSQUID / cbETH).
///         Convert-off: 1% of newly accrued inner yield to feeRecipient.
///         Convert-on: surplus → converter → WHYPE `notify` 99/1. Rate-bearing
///         listings pull only `exchangeRate` surplus. No fee on in/out.
contract LeafOFTAdapter is LeafOApp, ReentrancyGuard, LeafYieldFee {
    using SafeERC20 for IERC20;

    IERC20 public immutable innerToken;
    uint256 public depositCap;
    uint256 public totalLocked;

    event CapUpdated(uint256 cap);
    event BridgedOut(address indexed from, uint32 indexed dstEid, bytes32 to, uint256 amount, bytes32 guid);
    event BridgedIn(address indexed to, uint32 indexed srcEid, uint256 amount, bytes32 guid);
    event CreditAborted(address indexed to, uint256 amount);

    error ZeroAmount();
    error CapExceeded();
    error InsufficientLocked();
    error CannotPullInner();

    constructor(
        address token_,
        address endpoint_,
        address owner_,
        address guardian_,
        address feeRecipient_,
        uint256 depositCap_
    ) LeafOApp(endpoint_, owner_, guardian_) {
        if (token_ == address(0)) revert ZeroAddress();
        innerToken = IERC20(token_);
        depositCap = depositCap_;
        _initFee(feeRecipient_);
    }

    function openBridge() public override onlyOwner {
        if (innerSupplyCeiling == 0) revert LimitsUnset();
        super.openBridge();
    }

    function canonicalInner() public view override returns (address) {
        return address(innerToken);
    }

    function setDepositCap(uint256 cap) external onlyOwner {
        depositCap = cap;
        emit CapUpdated(cap);
    }

    /// @notice After dest `skipInbound`, return inner that never minted. Halt first.
    function abortCredit(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0) || amount == 0) revert ZeroAmount();
        if (health != Health.Halted && health != Health.Insolvent) revert NotSolvent();
        if (amount > totalLocked) revert InsufficientLocked();
        _requireCash(innerToken, amount, 0);
        totalLocked -= amount;
        innerToken.safeTransfer(to, amount);
        _syncAccounted(innerToken, 0);
        emit CreditAborted(to, amount);
    }

    function setFeeRecipient(address recipient) external onlyOwner {
        _setFeeRecipient(recipient);
    }

    function setConvertYieldToHype(bool enabled) external onlyOwner {
        _setConvertYieldToHype(enabled);
    }

    function setHarvester(address harvester_) external onlyOwner {
        _setHarvester(harvester_);
    }

    function setConverter(address converter_) external onlyOwner {
        _setConverter(converter_);
    }

    function setClaimTarget(address t, bool allowed) external onlyOwner {
        _setClaimTarget(address(innerToken), t, allowed);
    }

    function setClaimCall(address t, bytes4 selector) external onlyOwner {
        _setClaimCall(address(innerToken), t, selector);
    }

    function setRewardsSelector(bytes4 s) external onlyOwner {
        _setRewardsSelector(s);
    }

    function setRateKind(RateKind kind) external onlyOwner {
        _setRateKind(innerToken, kind);
    }

    /// @notice Anyone pays gas. Allowlisted Sign/TokenTable claim, as this lockbox.
    function pokeClaim(address t, bytes calldata data) external payable nonReentrant {
        _pokeClaim(address(innerToken), t, data);
    }

    /// @notice Squid-style: claimRewards(this, max) on the inner staking token.
    function pokeRewards() external payable nonReentrant {
        _pokeRewards(address(innerToken));
    }

    /// @notice Pull side-token surplus, or rate-implied inner surplus, to converter.
    function pullYield(IERC20 token, address to) external nonReentrant {
        if (msg.sender != harvester && msg.sender != owner()) revert NotHarvester();
        _requireConverter(to);
        if (address(token) == address(innerToken)) {
            if (rateKind == RateKind.None) revert CannotPullInner();
            uint256 before = lastRate;
            if (_tryPullRateYield(innerToken, 0, to) == 0) {
                if (lastRate == before) revert NoYield();
            }
            return;
        }
        _pullYield(token, innerToken, totalLocked, to);
    }

    function harvest() external nonReentrant {
        _requireInnerSupplyOk(innerToken);
        _harvestInner(innerToken, 0);
    }

    function harvestToken(IERC20 token) external nonReentrant {
        if (address(token) == address(innerToken)) {
            _requireInnerSupplyOk(innerToken);
            _harvestInner(innerToken, 0);
        } else {
            _harvestOther(token);
        }
    }

    function send(uint32 dstEid, bytes32 to, uint256 amount, address refund)
        public
        payable
        nonReentrant
        whenNotPaused
        returns (bytes32 guid)
    {
        if (amount == 0) revert ZeroAmount();
        if (to == bytes32(0)) revert ZeroAddress();
        _requireMint();
        _requireInnerSupplyOk(innerToken);

        _harvestInner(innerToken, 0);
        _tryPullRateYield(innerToken, 0, converter);

        uint256 got = _pull(msg.sender, amount);
        uint256 shares = _sharesForAssets(innerToken, got, totalLocked, 0);
        if (shares == 0) revert ZeroAmount();
        if (totalLocked + shares > depositCap) revert CapExceeded();
        totalLocked += shares;
        _accountDeposit(got);

        _takeQuota(shares);

        bytes memory payload = encodeBridge(to, shares);
        ILayerZeroEndpointV2.MessagingReceipt memory receipt =
            _lzSend(dstEid, payload, _defaultOptions(), refund == address(0) ? msg.sender : refund);
        emit BridgedOut(msg.sender, dstEid, to, got, receipt.guid);
        return receipt.guid;
    }

    function sendTo(uint32 dstEid, address to, uint256 amount) external payable returns (bytes32) {
        return send(dstEid, bytes32(uint256(uint160(to))), amount, msg.sender);
    }

    function _lzReceive(
        ILayerZeroEndpointV2.Origin calldata origin,
        bytes32 guid,
        bytes calldata message,
        address,
        bytes calldata
    ) internal override nonReentrant whenNotPaused {
        (bytes32 toB, uint256 amount) = _decodeBridge(message);
        address to = address(uint160(uint256(toB)));
        if (to == address(0) || amount == 0) revert ZeroAmount();
        if (amount > totalLocked) revert InsufficientLocked();
        _requireRedeem();
        _takeQuota(amount);
        if (rateKind == RateKind.None && innerToken.balanceOf(address(this)) < totalLocked) revert Underbacked();

        _harvestInner(innerToken, 0);
        _tryPullRateYield(innerToken, 0, converter);
        uint256 assetsOut = _assetsForShares(innerToken, amount, totalLocked, 0);
        _requireCash(innerToken, assetsOut, 0);
        totalLocked -= amount;
        innerToken.safeTransfer(to, assetsOut);
        _syncAccounted(innerToken, 0);
        emit BridgedIn(to, origin.srcEid, assetsOut, guid);
    }

    function _pull(address from, uint256 amount) internal returns (uint256 got) {
        uint256 before = innerToken.balanceOf(address(this));
        innerToken.safeTransferFrom(from, address(this), amount);
        got = innerToken.balanceOf(address(this)) - before;
        if (got == 0) revert ZeroAmount();
    }
}
