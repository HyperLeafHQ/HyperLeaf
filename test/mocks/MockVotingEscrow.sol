// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IVotingEscrow} from "../../src/interfaces/IVotingEscrow.sol";

/**
 * @title MockVotingEscrow
 * @notice Unit-test veNEST mirroring HyperEVM createLockFor / getNftState.
 * @dev While attached, amount+end are zeroed (mainnet). On mockDettach:
 *      - default liveDettachReset=true: set end = now+26w (matches onDettachFromManagedNFT)
 *      - opt-out liveDettachReset=false: restore prior end (legacy timed-unlock tests)
 */
contract MockVotingEscrow is ERC721 {
    uint256 public constant MAX_LOCK_TIME = 26 weeks;

    IERC20 public immutable nest;
    uint256 public nextId = 1;
    /// @notice When true (default), mockDettach resets end to now+26w like live Nest (HL-005).
    bool public liveDettachReset = true;

    mapping(uint256 => IVotingEscrow.LockedBalance) internal _locked;
    mapping(uint256 => bool) internal _attached;
    mapping(uint256 => uint256) internal _stashedAmount;
    mapping(uint256 => uint256) internal _stashedEnd;

    constructor(address nest_) ERC721("Mock veNEST", "veNEST") {
        nest = IERC20(nest_);
    }

    function setLiveDettachReset(bool enabled) external {
        liveDettachReset = enabled;
    }

    function createLockFor(
        uint256 amount_,
        uint256 lockDuration_,
        address to_,
        bool, /* shouldBoosted_ */
        bool withPermanentLock_,
        uint256 managedTokenIdForAttach_
    ) external returns (uint256 tokenId) {
        require(amount_ > 0, "zero");
        nest.transferFrom(msg.sender, address(this), amount_);
        tokenId = nextId++;
        uint256 end = withPermanentLock_ ? 0 : block.timestamp + lockDuration_;
        _locked[tokenId] = IVotingEscrow.LockedBalance({
            amount: int128(int256(amount_)), end: end, isPermanentLocked: withPermanentLock_
        });
        _mint(to_, tokenId);
        if (managedTokenIdForAttach_ > 0) {
            _attach(tokenId);
        }
    }

    function getNftState(uint256 tokenId_) external view returns (IVotingEscrow.TokenState memory) {
        return IVotingEscrow.TokenState({
            locked: _locked[tokenId_],
            isVoted: false,
            isAttached: _attached[tokenId_],
            lastTranferBlock: 0,
            pointEpoch: 0
        });
    }

    function nftStates(uint256 tokenId)
        external
        view
        returns (
            IVotingEscrow.LockedBalance memory locked,
            bool isVoted,
            bool isAttached,
            uint256 lastTranferBlock,
            uint256 pointEpoch
        )
    {
        locked = _locked[tokenId];
        isVoted = false;
        isAttached = _attached[tokenId];
        lastTranferBlock = 0;
        pointEpoch = 0;
    }

    /// @notice Test/adapter helper: simulate Voter.dettachFromManagedNFT.
    function mockDettach(uint256 tokenId) external {
        require(_attached[tokenId], "not attached");
        _attached[tokenId] = false;
        _locked[tokenId].amount = int128(int256(_stashedAmount[tokenId]));
        if (liveDettachReset) {
            _locked[tokenId].end = block.timestamp + MAX_LOCK_TIME;
        } else {
            _locked[tokenId].end = _stashedEnd[tokenId];
        }
        _locked[tokenId].isPermanentLocked = false;
        delete _stashedAmount[tokenId];
        delete _stashedEnd[tokenId];
    }

    function increase_unlock_time(uint256 tokenId, uint256 lockDuration) external {
        require(ownerOf(tokenId) == msg.sender, "not owner");
        require(!_attached[tokenId], "attached");
        require(!_locked[tokenId].isPermanentLocked, "permanent");
        _locked[tokenId].end = block.timestamp + lockDuration;
    }

    function withdraw(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "not owner");
        require(!_attached[tokenId], "attached");
        IVotingEscrow.LockedBalance memory lb = _locked[tokenId];
        require(!lb.isPermanentLocked && lb.end <= block.timestamp, "locked");
        require(lb.amount > 0, "empty");
        uint256 amount = uint256(int256(lb.amount));
        delete _locked[tokenId];
        _burn(tokenId);
        nest.transfer(msg.sender, amount);
    }

    function depositToAttachedNFT(uint256 tokenId_, uint256 amount_) external {
        require(_attached[tokenId_], "not attached");
        nest.transferFrom(msg.sender, address(this), amount_);
        _stashedAmount[tokenId_] += amount_;
    }

    function balanceOfNFT(uint256 tokenId) external view returns (uint256) {
        if (_attached[tokenId]) return 0;
        IVotingEscrow.LockedBalance memory lb = _locked[tokenId];
        if (lb.amount <= 0) return 0;
        if (!lb.isPermanentLocked && lb.end <= block.timestamp) return 0;
        return uint256(int256(lb.amount));
    }

    function merge(uint256, uint256) external pure {
        revert("not implemented");
    }

    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool) {
        address owner_ = ownerOf(tokenId);
        return (spender == owner_ || getApproved(tokenId) == spender || isApprovedForAll(owner_, spender));
    }

    function _attach(uint256 tokenId) internal {
        require(!_attached[tokenId], "already attached");
        IVotingEscrow.LockedBalance memory lb = _locked[tokenId];
        require(lb.amount > 0, "zero power");
        _attached[tokenId] = true;
        _stashedAmount[tokenId] = uint256(int256(lb.amount));
        _stashedEnd[tokenId] = lb.end;
        // Mainnet zeros amount+end while attached — vault must not rely on these fields.
        _locked[tokenId].amount = 0;
        _locked[tokenId].end = 0;
    }
}
