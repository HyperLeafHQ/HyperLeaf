// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {IBluaiStake} from "src/lz/IBluaiStake.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockBluai is ERC20 {
    constructor() ERC20("BLUAI", "BLUAI") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockBluaiStake is IBluaiStake {
    IERC20 public immutable token;
    mapping(address => uint256) public staked;
    uint256 public pending;
    uint256 public consumptionBps = 10_000;

    constructor(IERC20 t) {
        token = t;
    }

    function setConsumptionBps(uint256 bps) external {
        require(bps <= 10_000, "bps");
        consumptionBps = bps;
    }

    function seed(uint256 a) external {
        pending += a;
        MockBluai(address(token)).mint(address(this), a);
    }

    function stake(uint256 amount, uint256 years_) external override {
        require(years_ == 4, "years");
        uint256 accepted = amount * consumptionBps / 10_000;
        if (accepted > 0) token.transferFrom(msg.sender, address(this), accepted);
        staked[msg.sender] += accepted;
    }

    function claimAll() external override {
        uint256 a = pending;
        pending = 0;
        if (a > 0) token.transfer(msg.sender, a);
    }

    function unstake(uint256 amount) external override {
        uint256 a = amount > staked[msg.sender] ? staked[msg.sender] : amount;
        staked[msg.sender] -= a;
        token.transfer(msg.sender, a);
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30102;
    }

    function send(MessagingParams calldata, address) external payable returns (MessagingReceipt memory r) {
        r.guid = bytes32(uint256(1));
        r.fee = MessagingFee(msg.value, 0);
    }

    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee(0.01 ether, 0);
    }

    function setDelegate(address) external {}
    function setConfig(address, address, SetConfigParam[] calldata) external {}
    function getConfig(address, address, uint32, uint32) external pure returns (bytes memory) {
        return "";
    }
    function skip(address, uint32, bytes32, uint64) external {}
}

contract LeafBluaiLockboxTest is PegReady {
    MockEndpoint ep;
    MockBluai bluai;
    MockBluaiStake stake;
    LeafInboundLockbox box;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address user = address(0xBEEF);
    address converter = address(0xC0);

    function setUp() public {
        ep = new MockEndpoint();
        bluai = new MockBluai();
        stake = new MockBluaiStake(bluai);
        vm.prank(owner);
        box = new LeafInboundLockbox(address(bluai), address(ep), owner, guardian, feeTo, 1_000 ether);
        vm.startPrank(owner);
        box.setFarm(address(stake), IBluaiStake.stake.selector, 4, IBluaiStake.claimAll.selector);
        box.setFarmExit(IBluaiStake.unstake.selector);
        box.setPeer(40362, address(1));
        box.setHarvester(owner);
        box.setConverter(converter);
        box.setConvertYieldToHype(true);
        vm.stopPrank();
        _openSrc(box, owner, 1_000 ether);
        bluai.mint(user, 100 ether);
        vm.deal(user, 1 ether);
    }

    function testStakeFourYearsOnDeposit() public {
        vm.startPrank(user);
        bluai.approve(address(box), 40 ether);
        box.sendTo{value: 0.01 ether}(40362, user, 40 ether);
        vm.stopPrank();
        assertEq(stake.staked(address(box)), 40 ether);
        assertEq(bluai.balanceOf(address(box)), 0);
        assertEq(box.totalLocked(), 40 ether);
    }

    function testPartialFarmConsumptionRevertsAndLeavesAccountingUnchanged() public {
        vm.prank(owner);
        stake.setConsumptionBps(9_900);

        uint256 userBefore = bluai.balanceOf(user);
        uint256 boxBefore = bluai.balanceOf(address(box));
        uint256 lockedBefore = box.totalLocked();

        vm.startPrank(user);
        bluai.approve(address(box), 40 ether);
        vm.expectRevert(LeafInboundLockbox.BadStake.selector);
        box.sendTo{value: 0.01 ether}(40362, user, 40 ether);
        vm.stopPrank();

        assertEq(bluai.balanceOf(user), userBefore);
        assertEq(bluai.balanceOf(address(box)), boxBefore);
        assertEq(box.totalLocked(), lockedBefore);
        assertEq(stake.staked(address(box)), 0);
        assertFalse(box.farmPrincipalOut());
    }

    function testZeroFarmConsumptionRevertsAndLeavesAccountingUnchanged() public {
        vm.prank(owner);
        stake.setConsumptionBps(0);

        uint256 userBefore = bluai.balanceOf(user);
        uint256 boxBefore = bluai.balanceOf(address(box));
        uint256 lockedBefore = box.totalLocked();

        vm.startPrank(user);
        bluai.approve(address(box), 40 ether);
        vm.expectRevert(LeafInboundLockbox.BadStake.selector);
        box.sendTo{value: 0.01 ether}(40362, user, 40 ether);
        vm.stopPrank();

        assertEq(bluai.balanceOf(user), userBefore);
        assertEq(bluai.balanceOf(address(box)), boxBefore);
        assertEq(box.totalLocked(), lockedBefore);
        assertEq(stake.staked(address(box)), 0);
        assertFalse(box.farmPrincipalOut());
    }

    function testClaimAllThenPullIdleBluai() public {
        vm.startPrank(user);
        bluai.approve(address(box), 40 ether);
        box.sendTo{value: 0.01 ether}(40362, user, 40 ether);
        vm.stopPrank();

        stake.seed(5 ether);
        box.pokeRewards();
        assertEq(bluai.balanceOf(address(box)), 5 ether);

        vm.prank(owner);
        box.pullYield(bluai, converter);
        assertEq(bluai.balanceOf(converter), 5 ether);
        assertEq(bluai.balanceOf(address(box)), 0);
        assertEq(stake.staked(address(box)), 40 ether);
    }

    function testUnstakeThenRestake() public {
        vm.startPrank(user);
        bluai.approve(address(box), 40 ether);
        box.sendTo{value: 0.01 ether}(40362, user, 40 ether);
        vm.stopPrank();
        vm.prank(owner);
        box.farmUnstake(40 ether);
        assertEq(bluai.balanceOf(address(box)), 40 ether);
        assertEq(stake.staked(address(box)), 0);
        assertFalse(box.farmPrincipalOut());
        vm.prank(owner);
        box.restakeIdle();
        assertEq(stake.staked(address(box)), 40 ether);
        assertTrue(box.farmPrincipalOut());
        assertEq(bluai.balanceOf(address(box)), 0);
    }

    function testFarmConfigMutableBeforeFirstDeposit() public {
        vm.prank(owner);
        box.setFarmExit(bytes4(0x12345678));
        assertEq(box.farmExitSel(), bytes4(0x12345678));

        vm.prank(owner);
        box.setFarmStyle(LeafInboundLockbox.FarmStyle.AmountNative, 0.01 ether);
        assertEq(uint8(box.farmStyle()), uint8(LeafInboundLockbox.FarmStyle.AmountNative));
        assertEq(box.farmNativeFee(), 0.01 ether);

        vm.prank(owner);
        box.setFarmRequest(bytes4(0x87654321));
        assertEq(box.farmRequestSel(), bytes4(0x87654321));

        vm.prank(owner);
        box.setPublicRequestType(10, true);
        assertTrue(box.publicRequestType(10));

        vm.prank(owner);
        box.setShareExit(true);
        assertTrue(box.shareExitEnabled());
    }

    function testLiveFarmConfigCannotChangeAfterDeposit() public {
        vm.startPrank(user);
        bluai.approve(address(box), 40 ether);
        box.sendTo{value: 0.01 ether}(40362, user, 40 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(LeafInboundLockbox.FarmConfigFrozen.selector);
        box.setFarm(address(0xCAFE), bytes4(0x11111111), 8, bytes4(0x22222222));
        vm.expectRevert(LeafInboundLockbox.FarmConfigFrozen.selector);
        box.setFarmExit(bytes4(0x33333333));
        vm.expectRevert(LeafInboundLockbox.FarmConfigFrozen.selector);
        box.setFarmStyle(LeafInboundLockbox.FarmStyle.AmountNative, 1 ether);
        vm.expectRevert(LeafInboundLockbox.FarmConfigFrozen.selector);
        box.setFarmRequest(bytes4(0x44444444));
        vm.expectRevert(LeafInboundLockbox.FarmConfigFrozen.selector);
        box.setPublicRequestType(10, true);
        box.setShareExit(true);
        vm.stopPrank();

        assertEq(box.farm(), address(stake));
        assertEq(box.farmStakeSel(), IBluaiStake.stake.selector);
        assertEq(box.farmStakeArg(), 4);
        assertEq(box.farmClaimSel(), IBluaiStake.claimAll.selector);
        assertEq(box.farmExitSel(), IBluaiStake.unstake.selector);
        assertEq(uint8(box.farmStyle()), uint8(LeafInboundLockbox.FarmStyle.AmountYears));
        assertEq(box.farmNativeFee(), 0);
        assertEq(box.farmRequestSel(), bytes4(0));
        assertFalse(box.publicRequestType(10));
        assertTrue(box.shareExitEnabled());
    }
}
