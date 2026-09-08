// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IVeNft} from "src/lz/IVeNft.sol";

contract MockVeNft is ERC721 {
    mapping(uint256 => IVeNft.LockedBalance) internal _locked;
    mapping(uint256 => IVeNft.EscrowType) public escrowType;

    constructor() ERC721("veAERO", "veAERO") {}

    function mint(address to, uint256 id, int128 amount, bool permanent, uint256 end) external {
        _mint(to, id);
        _locked[id] = IVeNft.LockedBalance(amount, end, permanent);
        escrowType[id] = IVeNft.EscrowType.NORMAL;
    }

    function setLocked(uint256 id, int128 amount, bool permanent, uint256 end) external {
        _locked[id] = IVeNft.LockedBalance(amount, end, permanent);
    }

    function setType(uint256 id, IVeNft.EscrowType t) external {
        escrowType[id] = t;
    }

    function locked(uint256 id) external view returns (IVeNft.LockedBalance memory) {
        return _locked[id];
    }
}
