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

    event CapUpdated(uint256 cap);
    event BridgedOut(address indexed from, uint32 indexed dstEid, bytes32 to, uint256 amount, bytes32 guid);
    event BridgedIn(address indexed to, uint32 indexed srcEid, uint256 amount, bytes32 guid);
    event FarmSet(address farm, bytes4 stakeSel, uint256 arg, bytes4 claimSel);
    event FarmExitSel(bytes4 sel);
    event FarmUnstaked(uint256 amount);
    event RestakedIdle(uint256 amount);
    event ShareExitSet(bool on);

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

    function setDepositCap(uint256 cap) external onlyOwner {
        depositCap = cap;
        emit CapUpdated(cap);
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

    function setClaimTarget(address t, bool allowed) public virtual onlyOwner {
        if (farm != address(0) && t == farm) revert BadClaimTarget();
        _setClaimTarget(address(innerToken), t, allowed);
    }

    function setClaimCall(address t, bytes4 selector) public virtual onlyOwner {
        if (farm != address(0) && t == farm) revert BadClaimTarget();
        _setClaimCall(address(innerToken), t, selector);
    }

    function setFarm(address farm_, bytes4 stakeSel, uint256 arg, bytes4 claimSel) external onlyOwner {
        if (farm_ == address(innerToken)) revert BadClaimTarget();
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

    function pokeClaim(address t, bytes calldata data) external payable {
        _pokeClaim(address(innerToken), t, data);
    }

    function setRewardsSelector(bytes4 s) external onlyOwner {
        _setRewardsSelector(s);
    }

    function pokeRewards() external payable virtual {
        _afterPokeRewards();
        if (rewardsSelector != bytes4(0)) _pokeRewards(address(innerToken));
    }

    function _afterPokeRewards() internal virtual {
        if (farm == address(0) || farmClaimSel == bytes4(0)) return;
        (bool ok,) = farm.call(abi.encodeWithSelector(farmClaimSel));
        if (!ok) revert ClaimFailed();
    }

    function pullYield(IERC20 token, address to) external nonReentrant {
        if (msg.sender != harvester && msg.sender != owner()) revert NotHarvester();
        _requireConverter(to);
        _pullYield(token, innerToken, _principalReserved(), to);
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

    /// @dev Idle box: no-op. BLUAI: stake(amount, years) into `farm`.
    function _afterDeposit(uint256 got) internal virtual {
        if (farm == address(0) || got == 0) return;
        uint256 before = innerToken.balanceOf(address(this));
        innerToken.forceApprove(farm, got);
        (bool ok,) = farm.call(abi.encodeWithSelector(farmStakeSel, got, farmStakeArg));
        if (!ok || innerToken.balanceOf(address(this)) >= before) revert BadStake();
        farmPrincipalOut = true;
    }

    function _principalReserved() internal view virtual returns (uint256) {
        return farmPrincipalOut ? 0 : totalLocked;
    }
}
