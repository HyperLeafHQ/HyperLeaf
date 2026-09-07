// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {LeafOApp} from "./LeafOApp.sol";
import {ILayerZeroEndpointV2} from "./interfaces/ILayerZeroEndpointV2.sol";
import {ILeafHypeRewarder} from "./ILeafHypeRewarder.sol";

/// @title LeafOFT
/// @notice HyperEVM-side receipt. Mint on verified LZ message, burn to send back.
///         C1 closed listings override send() so the only exit is the market.
contract LeafOFT is LeafOApp, ERC20, ERC20Permit {
    error ZeroAmount();

    error SupplyCapExceeded();

    ILeafHypeRewarder public hypeRewarder;
    bytes32 public listingId;
    uint256 public supplyCap;

    event HypeRewarderSet(address indexed rewarder, bytes32 listingId);
    event BridgedOut(address indexed from, uint32 indexed dstEid, bytes32 to, uint256 amount, bytes32 guid);
    event BridgedIn(address indexed to, uint32 indexed srcEid, uint256 amount, bytes32 guid);
    event SupplyCapSet(uint256 cap);

    constructor(string memory name_, string memory symbol_, address endpoint_, address owner_, address guardian_)
        LeafOApp(endpoint_, owner_, guardian_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
    {}

    function setHypeRewarder(address rewarder, bytes32 listingId_) external onlyOwner {
        hypeRewarder = ILeafHypeRewarder(rewarder);
        listingId = listingId_;
        emit HypeRewarderSet(rewarder, listingId_);
    }

    function setSupplyCap(uint256 cap) public onlyOwner {
        if (cap == 0) revert LimitsUnset();
        supplyCap = cap;
        emit SupplyCapSet(cap);
    }

    function openBridge() public override onlyOwner {
        if (supplyCap == 0) revert LimitsUnset();
        super.openBridge();
    }

    function send(uint32 dstEid, bytes32 to, uint256 amount, address refund)
        public
        payable
        virtual
        whenNotPaused
        returns (bytes32 guid)
    {
        if (amount == 0) revert ZeroAmount();
        if (to == bytes32(0)) revert ZeroAddress();
        _requireRedeem();
        _takeQuota(amount);
        _burn(msg.sender, amount);
        bytes memory payload = encodeBridge(to, amount);
        ILayerZeroEndpointV2.MessagingReceipt memory receipt =
            _lzSend(dstEid, payload, _defaultOptions(), refund == address(0) ? msg.sender : refund);
        emit BridgedOut(msg.sender, dstEid, to, amount, receipt.guid);
        return receipt.guid;
    }

    function sendTo(uint32 dstEid, address to, uint256 amount) external payable whenNotPaused returns (bytes32) {
        return send(dstEid, bytes32(uint256(uint160(to))), amount, msg.sender);
    }

    function _lzReceive(
        ILayerZeroEndpointV2.Origin calldata origin,
        bytes32 guid,
        bytes calldata message,
        address,
        bytes calldata
    ) internal override whenNotPaused {
        (bytes32 toB, uint256 amount) = _decodeBridge(message);
        address to = address(uint160(uint256(toB)));
        if (to == address(0) || amount == 0) revert ZeroAmount();
        _requireMint();
        _takeQuota(amount);
        if (totalSupply() + amount > supplyCap) revert SupplyCapExceeded();
        _mint(to, amount);
        emit BridgedIn(to, origin.srcEid, amount, guid);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (address(hypeRewarder) != address(0)) {
            if (from != address(0) && to != address(0)) {
                hypeRewarder.settle(listingId, from);
                hypeRewarder.settle(listingId, to);
            } else if (from != address(0)) {
                hypeRewarder.settle(listingId, from);
            }
        }
        super._update(from, to, value);
        if (address(hypeRewarder) != address(0)) {
            if (from != address(0)) hypeRewarder.updateDebt(listingId, from);
            if (to != address(0)) hypeRewarder.updateDebt(listingId, to);
        }
    }
}
