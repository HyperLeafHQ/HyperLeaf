// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LeafOApp} from "./LeafOApp.sol";
import {LeafYieldFee} from "./LeafYieldFee.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";

/// @title LeafInboundLockbox
/// @notice C1 source lockbox. Reverse LZ rejected. 1% of new yield to feeRecipient.
contract LeafInboundLockbox is LeafOApp, ReentrancyGuard, LeafYieldFee {
    using SafeERC20 for IERC20;

    IERC20 public immutable innerToken;
    uint256 public depositCap;
    uint256 public totalLocked;

    /// @dev Optional external stake (BLUAI 4y). Principal leaves this box.
    address public farm;
    bytes4 public farmStakeSel;
    bytes4 public farmClaimSel;
    bytes4 public farmExitSel;
    uint256 public farmStakeArg;
    bool public farmPrincipalOut;
    bool public shareExitEnabled;

    /// @dev AmountYears = BLUAI `stake(amount, years)`. AmountNative = payable
    ///      one-arg stake (Orderly `stakeOrder(uint256)`). Dest chain is always
    ///      this chain — callers cannot pick Arb vs Base vs OP.
    enum FarmStyle {
        AmountYears,
        AmountNative
    }

    FarmStyle public farmStyle;
    uint256 public farmNativeFee;
    bytes4 public farmRequestSel;
    mapping(uint8 => bool) public publicRequestType;
    /// @dev Observed external-ledger stake for this identity. Not ERC-20
    ///      `balanceOf(this)` and not shared across CREATE2 twins on other chains.
    uint256 public ledgerPrincipal;

    event CapUpdated(uint256 cap);
    event BridgedOut(address indexed from, uint32 indexed dstEid, bytes32 to, uint256 amount, bytes32 guid);
    event BridgedIn(address indexed to, uint32 indexed srcEid, uint256 amount, bytes32 guid);
    event CreditAborted(address indexed to, uint256 amount);
    event FarmSet(address farm, bytes4 stakeSel, uint256 arg, bytes4 claimSel);
    event FarmExitSel(bytes4 sel);
    event FarmUnstaked(uint256 amount);
    event RestakedIdle(uint256 amount);
    event ShareExitSet(bool on);
    event FarmStyleSet(FarmStyle style, uint256 nativeFee);
    event FarmRequestSel(bytes4 sel);
    event FarmRequest(uint256 amount, uint8 payloadType, address indexed caller);
    event LedgerPrincipalReported(uint256 observed, address indexed caller);

    error ZeroAmount();
    error CapExceeded();
    error InboundOnly();
    error BadStake();
    error InsufficientLocked();

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

    function _requireRestoreProof() internal view override {
        super._requireRestoreProof();
        if (farmStyle == FarmStyle.AmountNative && farmPrincipalOut && ledgerPrincipal < totalLocked) {
            revert NotHealthy();
        }
    }

    function setDepositCap(uint256 cap) external onlyOwner {
        if (depositCap != 0 && cap > depositCap) revert CapIncrease();
        depositCap = cap;
        emit CapUpdated(cap);
    }

    /// @notice Same as adapter. Reverts if principal is still in the farm.
    function abortCredit(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0) || amount == 0) revert ZeroAmount();
        if (health != Health.Halted && health != Health.Insolvent) revert NotSolvent();
        if (farmPrincipalOut) revert BadStake();
        if (amount > totalLocked) revert InsufficientLocked();
        _requireCash(innerToken, amount, 0);
        totalLocked -= amount;
        innerToken.safeTransfer(to, amount);
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

    function setFarm(address farm_, bytes4 stakeSel, uint256 arg, bytes4 claimSel) external onlyOwner {
        if (farm_ == address(innerToken)) revert BadStake();
        farm = farm_;
        farmStakeSel = stakeSel;
        farmStakeArg = arg;
        farmClaimSel = claimSel;
        emit FarmSet(farm_, stakeSel, arg, claimSel);
    }

    function setFarmExit(bytes4 exitSel) external onlyOwner {
        farmExitSel = exitSel;
        emit FarmExitSel(exitSel);
    }

    function setShareExit(bool on) external onlyOwner {
        shareExitEnabled = on;
        emit ShareExitSet(on);
    }

    function setFarmStyle(FarmStyle style, uint256 nativeFee) external onlyOwner {
        farmStyle = style;
        farmNativeFee = nativeFee;
        emit FarmStyleSet(style, nativeFee);
    }

    function setFarmRequest(bytes4 sel) external onlyOwner {
        farmRequestSel = sel;
        emit FarmRequestSel(sel);
    }

    /// @dev Harvest types (Orderly 9/10/17) may be public. Unstake 2/3/4 stays owner.
    function setPublicRequestType(uint8 payloadType, bool ok) external onlyOwner {
        publicRequestType[payloadType] = ok;
    }

    /// @notice Ledger request as this lockbox. Calldata is (amount, type) only.
    function pokeFarmRequest(uint256 amount, uint8 payloadType) external payable nonReentrant {
        if (farm == address(0) || farmRequestSel == bytes4(0) || amount == 0) revert BadStake();
        if (!publicRequestType[payloadType] && msg.sender != owner()) revert BadStake();
        (bool ok,) = farm.call{value: msg.value}(abi.encodeWithSelector(farmRequestSel, amount, payloadType));
        if (!ok) revert BadStake();
        emit FarmRequest(amount, payloadType, msg.sender);
    }

    /// @notice Guardian/owner posts Orderly (or farm) stake for this address.
    ///         `farmPrincipalOut` is a location flag, not a proof.
    function reportLedgerPrincipal(uint256 observed) external onlyGuardian {
        ledgerPrincipal = observed;
        emit LedgerPrincipalReported(observed, msg.sender);
        if (farmPrincipalOut && observed < totalLocked && uint8(health) < uint8(Health.Degraded)) {
            health = Health.Degraded;
            emit HealthSet(Health.Degraded, msg.sender);
        }
    }

    /// @notice After the 4y lock: pull principal back. Then restakeIdle or setShareExit.
    function farmUnstake(uint256 amount) external onlyOwner nonReentrant {
        if (farm == address(0) || farmExitSel == bytes4(0) || amount == 0) revert BadStake();
        uint256 before = innerToken.balanceOf(address(this));
        (bool ok,) = farm.call(abi.encodeWithSelector(farmExitSel, amount));
        if (!ok || innerToken.balanceOf(address(this)) <= before) revert BadStake();
        farmPrincipalOut = false;
        emit FarmUnstaked(amount);
    }

    /// @notice No HyperEVM discount → lock idle BLUAI for another 4 years.
    function restakeIdle() external onlyOwner nonReentrant {
        uint256 idle = innerToken.balanceOf(address(this));
        if (idle == 0 || farm == address(0)) revert ZeroAmount();
        _afterDeposit(idle);
        emit RestakedIdle(idle);
    }

    function pokeRewards() external payable virtual nonReentrant {
        if (farm == address(0) || farmClaimSel == bytes4(0)) revert BadStake();
        _afterPokeRewards();
    }

    function _afterPokeRewards() internal virtual {
        if (farm == address(0) || farmClaimSel == bytes4(0)) return;
        (bool ok,) = farm.call(abi.encodeWithSelector(farmClaimSel));
        if (!ok) revert ClaimFailed();
    }

    function pullYield(IERC20 token, address to) external nonReentrant {
        if (msg.sender != harvester) revert NotHarvester();
        _requireConvertOn();
        _requireConverter(to);
        _pullYield(token, innerToken, _principalReserved(), to);
    }

    function harvest() external nonReentrant {
        _requireInnerSupplyOk(innerToken);
        _harvestInner(innerToken, 0);
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
        if (farmStyle == FarmStyle.AmountNative && farmPrincipalOut && ledgerPrincipal < totalLocked) {
            revert NotHealthy();
        }
        _requireInnerSupplyOk(innerToken);

        _harvestInner(innerToken, 0);

        uint256 got = _pull(msg.sender, amount);
        if (totalLocked + got > depositCap) revert CapExceeded();
        totalLocked += got;
        _accountDeposit(got);
        _afterDeposit(got);

        _takeQuota(got);

        bytes memory payload = encodeBridge(to, got);
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
        if (!shareExitEnabled) revert InboundOnly();
        (bytes32 toB, uint256 amount) = _decodeBridge(message);
        address to = address(uint160(uint256(toB)));
        if (to == address(0) || amount == 0) revert ZeroAmount();
        if (amount > totalLocked) revert InsufficientLocked();
        if (farmPrincipalOut) revert BadStake();
        _requireRedeem();
        _takeQuota(amount);
        _requireCash(innerToken, amount, 0);
        totalLocked -= amount;
        innerToken.safeTransfer(to, amount);
        emit BridgedIn(to, origin.srcEid, amount, guid);
    }

    function _pull(address from, uint256 amount) internal returns (uint256 got) {
        uint256 before = innerToken.balanceOf(address(this));
        innerToken.safeTransferFrom(from, address(this), amount);
        got = innerToken.balanceOf(address(this)) - before;
        if (got == 0) revert ZeroAmount();
    }

    /// @dev Idle box: no-op. BLUAI: stake(amount, years). ORDER: payable stakeOrder(amount).
    function _afterDeposit(uint256 got) internal virtual {
        if (farm == address(0) || got == 0) return;
        uint256 before = innerToken.balanceOf(address(this));
        innerToken.forceApprove(farm, got);
        bool ok;
        if (farmStyle == FarmStyle.AmountNative) {
            (ok,) = farm.call{value: farmNativeFee}(abi.encodeWithSelector(farmStakeSel, got));
        } else {
            (ok,) = farm.call(abi.encodeWithSelector(farmStakeSel, got, farmStakeArg));
        }
        if (!ok || innerToken.balanceOf(address(this)) >= before) revert BadStake();
        // Token left this box. Ledger credit is async (Orderly LZ). Flag only.
        farmPrincipalOut = true;
    }

    function _principalReserved() internal view virtual returns (uint256) {
        return farmPrincipalOut ? 0 : totalLocked;
    }
}
