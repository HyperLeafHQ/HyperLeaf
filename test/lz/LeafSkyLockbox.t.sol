// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISkyLockstake} from "src/lz/ISkyLockstake.sol";

contract MockSky is ERC20 {
    constructor() ERC20("SKY", "SKY") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
    function burn(address from, uint256 a) external {
        _burn(from, a);
    }
}

contract MockEngine is ISkyLockstake {
    IERC20 public immutable skyToken;
    address public immutable lsskyAddr;
    address public immutable usdsAddr;
    mapping(address => uint256) public locked;
    uint256 public pending;
    address public lastDelegate;
    address public lastFarm;
    bool public opened;

    constructor(IERC20 s) {
        skyToken = s;
        lsskyAddr = address(s);
        usdsAddr = address(s);
    }

    function fee() external pure override returns (uint256) {
        return 0;
    }
    function sky() external view override returns (address) {
        return address(skyToken);
    }
    function lssky() external view override returns (address) {
        return lsskyAddr;
    }
    function usds() external view override returns (address) {
        return usdsAddr;
    }
    function farms(address) external pure override returns (uint8) {
        return 1;
    }

    function seed(uint256 a) external {
        pending += a;
        MockSky(address(skyToken)).mint(address(this), a);
    }

    function open(uint256) external override returns (address) {
        opened = true;
        return address(this);
    }

    function lock(address, uint256, uint256 wad, uint16) external override {
        skyToken.transferFrom(msg.sender, address(this), wad);
        locked[msg.sender] += wad;
    }

    function free(address, uint256, address to, uint256 wad) external override returns (uint256 freed) {
        require(locked[msg.sender] >= wad, "lock");
        locked[msg.sender] -= wad;
        freed = wad;
        skyToken.transfer(to, freed);
    }

    function selectFarm(address, uint256, address farm_, uint16) external override {
        lastFarm = farm_;
    }

    function selectVoteDelegate(address, uint256, address d) external override {
        lastDelegate = d;
    }

    function getReward(address, uint256, address, address to) external override returns (uint256 amt) {
        amt = pending;
        pending = 0;
        if (amt > 0) skyToken.transfer(to, amt);
    }
}

contract SkyLockstakePocTest is Test {
    MockSky skyTok;
    MockEngine engine;
    address box = address(this);
    address farm = address(0xF4);

    function setUp() public {
        skyTok = new MockSky();
        engine = new MockEngine(skyTok);
        engine.open(0);
        engine.selectFarm(box, 0, farm, 0);
        skyTok.mint(box, 100 ether);
        skyTok.approve(address(engine), type(uint256).max);
    }

    function testOpenSelectLockRewardFree() public {
        assertTrue(engine.opened());
        assertEq(engine.lastFarm(), farm);
        assertEq(engine.fee(), 0);

        engine.lock(box, 0, 40 ether, 0);
        assertEq(engine.locked(box), 40 ether);

        engine.seed(2 ether);
        uint256 got = engine.getReward(box, 0, farm, box);
        assertEq(got, 2 ether);

        engine.selectVoteDelegate(box, 0, address(0xDE1));
        assertEq(engine.lastDelegate(), address(0xDE1));

        uint256 freed = engine.free(box, 0, box, 40 ether);
        assertEq(freed, 40 ether);
    }
}
