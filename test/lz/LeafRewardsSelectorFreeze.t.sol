// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, StdStorage, stdStorage} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";

contract SelectorFreezeEndpoint {
    function setDelegate(address) external {}
}

contract SelectorFreezeToken is ERC20 {
    uint256 public pokeCalls;

    constructor() ERC20("Selector Freeze Token", "SFT") {}

    function claimRewards(address, uint256) external {
        pokeCalls++;
    }
}

contract SelectorFreezeTarget {
    uint256 public calls;
    address public claimedAsset;
    address public claimedTo;

    fallback() external payable {
        calls++;
        if (msg.sig == bytes4(0xbb492bf5)) {
            claimedTo = address(uint160(uint256(calldataload(36))));
            claimedAsset = address(uint160(uint256(calldataload(100))));
        }
    }
}

contract LeafRewardsSelectorFreezeTest is Test {
    using stdStorage for StdStorage;

    SelectorFreezeEndpoint endpoint;
    SelectorFreezeToken token;
    LeafOFTAdapter adapter;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeRecipient = address(0xFEE);

    bytes4 constant CLAIM_REWARDS = bytes4(0x9a99b4f0);
    bytes4 constant OTHER_CLAIM_REWARDS = bytes4(0x12345678);
    bytes4 constant CLAIM_ALL_REWARDS = bytes4(0xbb492bf5);

    function setUp() public {
        endpoint = new SelectorFreezeEndpoint();
        token = new SelectorFreezeToken();
        vm.prank(owner);
        adapter = new LeafOFTAdapter(
            address(token),
            address(endpoint),
            owner,
            guardian,
            feeRecipient,
            1_000_000 ether
        );
    }

    function testSelectorCanBeConfiguredBeforeFirstDeposit() public {
        vm.prank(owner);
        adapter.setRewardsSelector(CLAIM_REWARDS);
        assertEq(adapter.rewardsSelector(), CLAIM_REWARDS);
    }

    function testSelectorCannotChangeAfterFirstDeposit() public {
        vm.prank(owner);
        adapter.setRewardsSelector(CLAIM_REWARDS);

        stdstore.target(address(adapter)).sig(adapter.totalLocked.selector).checked_write(1);

        vm.prank(owner);
        vm.expectRevert(LeafOFTAdapter.ConfigFrozen.selector);
        adapter.setRewardsSelector(OTHER_CLAIM_REWARDS);

        assertEq(adapter.rewardsSelector(), CLAIM_REWARDS);
    }

    function testRewardsTargetCannotChangeAfterFirstDeposit() public {
        SelectorFreezeTarget target1 = new SelectorFreezeTarget();
        SelectorFreezeTarget target2 = new SelectorFreezeTarget();

        vm.startPrank(owner);
        adapter.setRewardsSelector(CLAIM_ALL_REWARDS);
        adapter.setRewardsTarget(address(target1));
        vm.stopPrank();

        stdstore.target(address(adapter)).sig(adapter.totalLocked.selector).checked_write(1);

        vm.prank(owner);
        vm.expectRevert(LeafOFTAdapter.ConfigFrozen.selector);
        adapter.setRewardsTarget(address(target2));

        assertEq(adapter.rewardsTarget(), address(target1));
    }

    function testClaimRewardsSelectorMatchesProductionAbi() public pure {
        assertEq(bytes4(keccak256("claimRewards(address,uint256)")), CLAIM_REWARDS);
    }

    function testPokeRewardsUsesConfiguredExternalTargetForClaimAll() public {
        SelectorFreezeTarget target = new SelectorFreezeTarget();

        vm.startPrank(owner);
        adapter.setRewardsSelector(CLAIM_ALL_REWARDS);
        adapter.setRewardsTarget(address(target));
        vm.stopPrank();

        adapter.pokeRewards();

        assertEq(target.calls(), 1);
        assertEq(target.claimedAsset(), address(token));
        assertEq(target.claimedTo(), address(adapter));
        assertEq(token.pokeCalls(), 0);
    }
}
