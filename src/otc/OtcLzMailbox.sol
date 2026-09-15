// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LeafClaimPeer} from "../lz/LeafClaimPeer.sol";
import {ILayerZeroEndpointV2} from "../lz/interfaces/ILayerZeroEndpointV2.sol";
import {IOtcMailbox} from "./IOtcMailbox.sol";
import {OtcRemoteLock} from "./OtcRemoteLock.sol";
import {OtcClaim} from "./OtcClaim.sol";

/// @notice Production mailbox. Deploy one on the source chain (`isSource=true`)
///         and one on HyperEVM (`isSource=false`). Wire peers, then freezeConfig.
///         Same-chain mailbox must not be used on two live networks.
contract OtcLzMailbox is LeafClaimPeer, IOtcMailbox {
    uint8 public constant OP_MINT = 1;
    uint8 public constant OP_RELEASE = 2;

    bool public immutable isSource;
    address public lock;
    address public claim;

    error AlreadySet();
    error WrongSide();
    error NotLock();
    error NotClaim();
    error BadOp();
    error Zero();

    constructor(address endpoint_, address owner_, address guardian_, bool isSource_)
        LeafClaimPeer(endpoint_, owner_, guardian_)
    {
        isSource = isSource_;
    }

    function setLock(address l) external onlyOwner {
        if (!isSource) revert WrongSide();
        if (lock != address(0)) revert AlreadySet();
        if (l == address(0)) revert Zero();
        lock = l;
    }

    function setClaim(address c) external onlyOwner {
        if (isSource) revert WrongSide();
        if (claim != address(0)) revert AlreadySet();
        if (c == address(0)) revert Zero();
        claim = c;
    }

    function notifyDeposit(address destTo, uint256 amount) external payable whenNotPaused {
        if (!isSource) revert WrongSide();
        if (msg.sender != lock) revert NotLock();
        if (destTo == address(0) || amount == 0) revert Zero();
        _lzSend(remoteEid, abi.encode(OP_MINT, destTo, amount), msg.sender);
    }

    function notifyRedeem(address srcTo, uint256 amount) external payable whenNotPaused {
        if (isSource) revert WrongSide();
        if (msg.sender != claim) revert NotClaim();
        if (srcTo == address(0) || amount == 0) revert Zero();
        _lzSend(remoteEid, abi.encode(OP_RELEASE, srcTo, amount), msg.sender);
    }

    function quoteMint(address destTo, uint256 amount) external view returns (uint256) {
        return quote(remoteEid, abi.encode(OP_MINT, destTo, amount), _defaultOptions());
    }

    function quoteRedeem(address srcTo, uint256 amount) external view returns (uint256) {
        return quote(remoteEid, abi.encode(OP_RELEASE, srcTo, amount), _defaultOptions());
    }

    function _lzReceive(ILayerZeroEndpointV2.Origin calldata, bytes32, bytes calldata message, address, bytes calldata)
        internal
        override
    {
        (uint8 op, address to, uint256 amount) = abi.decode(message, (uint8, address, uint256));
        if (op == OP_MINT) {
            if (isSource) revert WrongSide();
            OtcClaim(claim).mint(to, amount);
        } else if (op == OP_RELEASE) {
            if (!isSource) revert WrongSide();
            OtcRemoteLock(lock).release(to, amount);
        } else {
            revert BadOp();
        }
    }
}
