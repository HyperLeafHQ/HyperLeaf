// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {ILeafRewardSource} from "src/lz/ILeafRewardSource.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockToken is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    IERC20 public payout;
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
    function setPayout(address p) external {
        payout = IERC20(p);
    }
    function claimRewards(address to, uint256) external {
        if (address(payout) == address(0)) return;
        uint256 a = payout.balanceOf(address(this));
        if (a > 0) payout.transfer(to, a);
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    uint32 public eid;
    constructor(uint32 eid_) {
        eid = eid_;
    }
    function send(MessagingParams calldata _params, address) external payable returns (MessagingReceipt memory r) {
        r.guid = keccak256(abi.encode(_params, block.number));
        r.nonce = 1;
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

/// @dev Simulates Squid/BLUAI: claim pays QUID into the lockbox, never touches xSQUID.
contract MockQuidFarm is ILeafRewardSource {
    MockToken public immutable quid;
    uint256 public pending;

    constructor(MockToken quid_) {
        quid = quid_;
    }

    function seed(uint256 amount) external {
        pending += amount;
        quid.mint(address(this), amount);
    }

    function harvest(address lockbox) external {
        uint256 a = pending;
        pending = 0;
        if (a > 0) quid.transfer(lockbox, a);
    }
}

contract LeafHarvestSplitTest is PegReady {
    MockEndpoint ep;
    MockToken xsquid;
    MockToken quid;
    MockToken bluai;
    LeafOFTAdapter adapter;
    LeafInboundLockbox lockbox;
    MockQuidFarm farm;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address harvester = address(0x1111);
    address converter = address(0xC0);
    address alice = address(0xA1);

    function setUp() public {
        ep = new MockEndpoint(30184);
        xsquid = new MockToken("xSQUID", "xSQUID");
        quid = new MockToken("QUID", "QUID");
        bluai = new MockToken("BLUAI", "BLUAI");
        farm = new MockQuidFarm(quid);
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(xsquid), address(ep), owner, guardian, feeTo, 10_000e18);
        lockbox = new LeafInboundLockbox(address(bluai), address(ep), owner, guardian, feeTo, 10_000e18);
        adapter.setHarvester(harvester);
        adapter.setConverter(converter);
        adapter.setConvertYieldToHype(true);
        adapter.setPeer(30367, address(1));
        lockbox.setHarvester(harvester);
        lockbox.setConverter(converter);
        lockbox.setConvertYieldToHype(true);
        lockbox.setPeer(30367, address(1));
        vm.stopPrank();
        _openSrc(adapter, owner, 10_000e18);
        _openSrc(lockbox, owner, 10_000e18);
        xsquid.mint(alice, 100e18);
        bluai.mint(alice, 100e18);
        vm.deal(alice, 1 ether);
    }

    function testAnyoneCanPokeHarvestRewards() public {
        farm.seed(7e18);
        vm.prank(alice);
        farm.harvest(address(adapter));
        assertEq(quid.balanceOf(address(adapter)), 7e18);
        assertEq(xsquid.balanceOf(address(adapter)), 0);
    }

    function testCannotPullXsquidInner() public {
        vm.startPrank(alice);
        xsquid.approve(address(adapter), 50e18);
        adapter.sendTo{value: 0.01 ether}(30367, alice, 50e18);
        vm.stopPrank();
        xsquid.mint(address(adapter), 3e18);
        vm.prank(harvester);
        vm.expectRevert(LeafOFTAdapter.CannotPullInner.selector);
        adapter.pullYield(xsquid, converter);
    }

    function testHarvesterPullsQuidOnly() public {
        farm.seed(4e18);
        farm.harvest(address(adapter));
        vm.prank(harvester);
        vm.expectRevert();
        adapter.pullYield(quid, harvester);
        vm.prank(harvester);
        adapter.pullYield(quid, converter);
        assertEq(quid.balanceOf(converter), 4e18);
        assertEq(quid.balanceOf(address(adapter)), 0);
    }

    function testUnknownSideTokenHarvesterCanSweepDust() public {
        MockToken dust = new MockToken("DUST", "DUST");
        dust.mint(address(adapter), 1e18);
        vm.prank(harvester);
        adapter.pullYield(dust, converter);
        assertEq(dust.balanceOf(converter), 1e18);
    }

    function testBluaiPullsInnerSurplusNotPrincipal() public {
        vm.startPrank(alice);
        bluai.approve(address(lockbox), 50e18);
        lockbox.sendTo{value: 0.01 ether}(30367, alice, 50e18);
        vm.stopPrank();
        bluai.mint(address(lockbox), 8e18);
        vm.prank(harvester);
        lockbox.pullYield(bluai, converter);
        assertEq(bluai.balanceOf(converter), 8e18);
        assertEq(bluai.balanceOf(address(lockbox)), 50e18);
    }

    function testPokeRewardsClaimsQuidToLockbox() public {
        bytes4 sel = bytes4(keccak256("claimRewards(address,uint256)"));
        assertEq(sel, bytes4(0x9a99b4f0));
        xsquid.setPayout(address(quid));
        quid.mint(address(xsquid), 27e18);
        vm.prank(alice);
        vm.expectRevert();
        adapter.pokeRewards();
        vm.prank(owner);
        adapter.setRewardsSelector(sel);
        adapter.pokeRewards();
        assertEq(quid.balanceOf(address(adapter)), 27e18);
        vm.startPrank(alice);
        xsquid.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(30367, alice, 10e18);
        vm.stopPrank();
        assertEq(xsquid.balanceOf(address(adapter)), 10e18);
        vm.prank(harvester);
        adapter.pullYield(quid, converter);
        assertEq(quid.balanceOf(converter), 27e18);
        vm.prank(harvester);
        vm.expectRevert();
        adapter.pullYield(xsquid, converter);
    }

    function testRewardsSelectorRejectsSquidRedeem() public {
        bytes4 redeem = bytes4(keccak256("redeem(address,uint256)"));
        assertEq(redeem, bytes4(0x1e9a6950));
        vm.prank(owner);
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(redeem);
        vm.prank(owner);
        adapter.setRewardsSelector(bytes4(0x9a99b4f0));
        assertEq(adapter.rewardsSelector(), bytes4(0x9a99b4f0));
    }
}
