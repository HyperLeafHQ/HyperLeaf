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
    IERC20 public immutable sky;
    mapping(address => uint256) public locked;
    uint256 public pending;
    address public lastDelegate;
    address public lastFarm;
    bool public opened;

    constructor(IERC20 s) {
        sky = s;
    }

    function seed(uint256 a) external {
        pending += a;
        MockSky(address(sky)).mint(address(this), a);
    }

    function open(uint256) external override returns (address) {
        opened = true;
        return address(this);
    }

    function lock(address, uint256, uint256 wad, uint16) external override {
        sky.transferFrom(msg.sender, address(this), wad);
        locked[msg.sender] += wad;
    }

    function free(address, uint256, address to, uint256 wad) external override returns (uint256 freed) {
        require(locked[msg.sender] >= wad, "lock");
        locked[msg.sender] -= wad;
        uint256 fee = wad / 20;
        freed = wad - fee;
        MockSky(address(sky)).burn(address(this), fee);
        sky.transfer(to, freed);
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
        if (amt > 0) sky.transfer(to, amt);
    }
}

/// @notice PoC of the Sky V1 path without the LZ box (IR too fat to inherit inbound).
contract SkyLockstakePocTest is Test {
    MockSky sky;
    MockEngine engine;
    address box = address(this);
    address farm = address(0xF4);

    function setUp() public {
        sky = new MockSky();
        engine = new MockEngine(sky);
        engine.open(0);
        engine.selectFarm(box, 0, farm, 0);
        sky.mint(box, 100 ether);
        sky.approve(address(engine), type(uint256).max);
    }

    function testOpenSelectLockRewardFree() public {
        assertTrue(engine.opened());
        assertEq(engine.lastFarm(), farm);

        engine.lock(box, 0, 40 ether, 0);
        assertEq(engine.locked(box), 40 ether);
        assertEq(sky.balanceOf(box), 60 ether);

        engine.seed(2 ether);
        uint256 got = engine.getReward(box, 0, farm, box);
        assertEq(got, 2 ether);

        engine.selectVoteDelegate(box, 0, address(0xDE1));
        assertEq(engine.lastDelegate(), address(0xDE1));

        uint256 freed = engine.free(box, 0, box, 40 ether);
        assertEq(freed, 38 ether);
        assertEq(engine.locked(box), 0);
    }
}
