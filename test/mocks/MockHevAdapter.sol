// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IHevAdapter} from "../../src/interfaces/IHevAdapter.sol";
import {IVotingEscrow} from "../../src/interfaces/IVotingEscrow.sol";
import {MockVotingEscrow} from "./MockVotingEscrow.sol";

/**
 * @title MockHevAdapter
 * @notice Unit-test stub: optional NFT custody + injectable HYPE rewards.
 *         Detach calls MockVotingEscrow.mockDettach when NFT was attached via createLockFor.
 */
contract MockHevAdapter is IHevAdapter, IERC721Receiver {
    IVotingEscrow public ve;
    IERC20 public hype;
    address public vault;

    bool public custodyEnabled;
    mapping(uint256 => bool) public deposited;
    mapping(uint256 => uint256) public pending;

    constructor(address ve_, address hype_, address vault_) {
        ve = IVotingEscrow(ve_);
        hype = IERC20(hype_);
        vault = vault_;
    }

    function setVault(address vault_) external {
        vault = vault_;
    }

    function setCustodyEnabled(bool enabled) external {
        custodyEnabled = enabled;
    }

    /// @notice Tests inject claimable HYPE per token (adapter holds tokens).
    function seedReward(uint256 tokenId, uint256 amount) external {
        pending[tokenId] += amount;
        require(hype.transferFrom(msg.sender, address(this), amount), "transfer");
    }

    function depositVeNFT(uint256 tokenId) external {
        require(msg.sender == vault, "only vault");
        require(!deposited[tokenId], "already deposited");
        // Idempotent vs createLockFor(..., managedTokenId=1): already attached → record only.
        IVotingEscrow.TokenState memory st = ve.getNftState(tokenId);
        if (!st.isAttached) {
            // Unit tests: no live Voter; attach is optional no-op unless createLockFor did it.
        }
        deposited[tokenId] = true;
        if (custodyEnabled) {
            ve.transferFrom(msg.sender, address(this), tokenId);
        }
    }

    function withdrawVeNFT(uint256 tokenId) external {
        require(msg.sender == vault, "only vault");
        require(deposited[tokenId], "not deposited");
        deposited[tokenId] = false;
        IVotingEscrow.TokenState memory st = ve.getNftState(tokenId);
        if (st.isAttached) {
            MockVotingEscrow(address(ve)).mockDettach(tokenId);
        }
        if (custodyEnabled && ve.ownerOf(tokenId) == address(this)) {
            ve.transferFrom(address(this), msg.sender, tokenId);
        }
    }

    function claimHype(uint256[] calldata tokenIds, address recipient) external returns (uint256 amountClaimed) {
        require(msg.sender == vault, "only vault");
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            uint256 amt = pending[tokenIds[i]];
            if (amt > 0) {
                pending[tokenIds[i]] = 0;
                amountClaimed += amt;
            }
        }
        if (amountClaimed > 0) {
            require(hype.transfer(recipient, amountClaimed), "hype");
        }
    }

    function pendingHype(uint256 tokenId) external view returns (uint256) {
        return pending[tokenId];
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
