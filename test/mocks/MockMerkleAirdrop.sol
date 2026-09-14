// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockMerkleAirdrop
 * @notice Faithful stub of the live Nest WHypeAirdrop (0x33afCe556508A39181a0609288c3E93611a00905):
 *         - leaf = keccak256(bytes.concat(keccak256(abi.encode(addr_, amount_)))) (double hash)
 *         - amount_ is CUMULATIVE; only the unclaimed delta is paid to addr_
 *         - reverts AlreadyClaimed when amount_ <= claimed[addr_]
 *         - admin (owner) can rotate the root, covering cross-week cumulative claims
 */
contract MockMerkleAirdrop is Ownable {
    IERC20 public immutable hype;
    bytes32 public rootHash;
    mapping(address => uint256) public claimed;

    error AlreadyClaimed();
    error InvalidProof();

    constructor(address hype_) Ownable(msg.sender) {
        hype = IERC20(hype_);
    }

    /// @notice Admin root rotation (live: ROOT_SETTER_ROLE rotates weekly, Thursday 00:00 UTC).
    function setRoot(bytes32 root_) external onlyOwner {
        rootHash = root_;
    }

    function claim(bytes32[] calldata proof, address addr_, uint256 amount_) external {
        bool valid = MerkleProof.verify(
            proof, rootHash, keccak256(bytes.concat(keccak256(abi.encode(addr_, amount_))))
        );
        if (!valid) revert InvalidProof();
        uint256 claimedCache = claimed[addr_];
        if (claimedCache >= amount_) revert AlreadyClaimed();
        uint256 delta = amount_ - claimedCache;
        claimed[addr_] = amount_;
        require(hype.transfer(addr_, delta), "xfer");
    }
}
