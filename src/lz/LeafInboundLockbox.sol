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

    event CapUpdated(uint256 cap);
    event BridgedOut(address indexed from, uint32 indexed dstEid, bytes32 to, uint256 amount, bytes32 guid);

    error ZeroAmount();
    error CapExceeded();
    error InboundOnly();

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

    function pullYield(IERC20 token, address to) external nonReentrant {
        if (msg.sender != harvester && msg.sender != owner()) revert NotHarvester();
        _requireConverter(to);
        _pullYield(token, innerToken, totalLocked, to);
    }

    function harvest() external nonReentrant {
        _harvestInner(innerToken, 0);
    }

    function harvestToken(IERC20 token) external nonReentrant {
        if (address(token) == address(innerToken)) {
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

        _harvestInner(innerToken, 0);

        uint256 got = _pull(msg.sender, amount);
        if (totalLocked + got > depositCap) revert CapExceeded();
        totalLocked += got;
        _accountDeposit(got);
        _afterDeposit(got);

        bytes memory payload = abi.encode(to, got);
        ILayerZeroEndpointV2.MessagingReceipt memory receipt =
            _lzSend(dstEid, payload, _defaultOptions(), refund == address(0) ? msg.sender : refund);
        emit BridgedOut(msg.sender, dstEid, to, got, receipt.guid);
        return receipt.guid;
    }

    function sendTo(uint32 dstEid, address to, uint256 amount) external payable returns (bytes32) {
        return send(dstEid, bytes32(uint256(uint160(to))), amount, msg.sender);
    }

    function _lzReceive(ILayerZeroEndpointV2.Origin calldata, bytes32, bytes calldata, address, bytes calldata)
        internal
        pure
        override
    {
        revert InboundOnly();
    }

    function _pull(address from, uint256 amount) internal returns (uint256 got) {
        uint256 before = innerToken.balanceOf(address(this));
        innerToken.safeTransferFrom(from, address(this), amount);
        got = innerToken.balanceOf(address(this)) - before;
        if (got == 0) revert ZeroAmount();
    }

    /// @dev C1 default: tokens stay in this box. hVIRTUALMAX stakes into Virtuals.
    function _afterDeposit(uint256) internal virtual {}
}
