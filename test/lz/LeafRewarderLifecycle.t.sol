// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafHypeRewarder} from "src/lz/LeafHypeRewarder.sol";

contract LifecycleEndpoint {
    function setDelegate(address) external {}
}

contract LifecycleToken is ERC20 {
    constructor() ERC20("WHYPE", "WHYPE") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TestLeafOFT is LeafOFT {
    constructor(address endpoint_, address owner_, address guardian_)
        LeafOFT("Hyperleaf Test", "hTEST", endpoint_, owner_, guardian_)
    {}

    function mintForTest(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LeafRewarderLifecycleTest is Test {
    LifecycleEndpoint endpoint;
    LifecycleToken whype;
    TestLeafOFT oft;
    LeafHypeRewarder rewarder;

    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeRecipient = address(0xFEE);
    address alice = address(0xA1);
    address bob = address(0xB2);
    bytes32 constant ID = keccak256("hlifecycle");

    function setUp() public {
        endpoint = new LifecycleEndpoint();
        whype = new LifecycleToken();

        vm.startPrank(owner);
        oft = new TestLeafOFT(address(endpoint), owner, guardian);
        rewarder = new LeafHypeRewarder(address(whype), owner, feeRecipient);
        oft.setHypeRewarder(address(rewarder), ID);
        rewarder.register(ID, address(oft));
        vm.stopPrank();
    }

    function testActiveDisableCannotRebindSameRewarder() public {
        oft.mintForTest(alice, 100e18);

        vm.prank(owner);
        oft.setHypeRewarder(address(0), ID);

        assertTrue(oft.rewarderDisabled());
        assertEq(address(oft.hypeRewarder()), address(rewarder));
        assertFalse(oft.rewardsActive());

        vm.prank(owner);
        vm.expectRevert(LeafOFT.RewarderFrozen.selector);
        oft.setHypeRewarder(address(rewarder), ID);
    }

    function testDisabledLifecycleRejectsNewNotify() public {
        oft.mintForTest(alice, 100e18);
        whype.mint(address(this), 100e18);
        whype.approve(address(rewarder), type(uint256).max);
        rewarder.notify(ID, 100e18);
        assertEq(rewarder.pending(ID, alice), 99e18);

        vm.prank(owner);
        oft.setHypeRewarder(address(0), ID);

        vm.expectRevert(LeafHypeRewarder.RewardsDisabled.selector);
        rewarder.notify(ID, 100e18);
    }

    function testHolderEnteringAfterDisableGetsNoHistoricalReward() public {
        oft.mintForTest(alice, 100e18);
        whype.mint(address(this), 100e18);
        whype.approve(address(rewarder), type(uint256).max);
        rewarder.notify(ID, 100e18);

        vm.prank(owner);
        oft.setHypeRewarder(address(0), ID);

        oft.mintForTest(bob, 100e18);
        assertEq(rewarder.pending(ID, bob), 0);
        assertEq(rewarder.pending(ID, alice), 99e18);
    }

    function testPreDisableAccruedRewardSurvivesExitWithoutDuplicate() public {
        oft.mintForTest(alice, 100e18);
        whype.mint(address(this), 100e18);
        whype.approve(address(rewarder), type(uint256).max);
        rewarder.notify(ID, 100e18);
        uint256 accruedBeforeExit = rewarder.pending(ID, alice);
        assertEq(accruedBeforeExit, 99e18);

        vm.prank(owner);
        oft.setHypeRewarder(address(0), ID);

        vm.prank(alice);
        oft.transfer(bob, 100e18);

        assertEq(rewarder.pending(ID, alice), accruedBeforeExit);
        assertEq(rewarder.pending(ID, bob), 0);

        vm.prank(alice);
        rewarder.claim(ID, alice);
        assertEq(whype.balanceOf(alice), accruedBeforeExit);
        assertEq(rewarder.pending(ID, alice), 0);
    }
}
