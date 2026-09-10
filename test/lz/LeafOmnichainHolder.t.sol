// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LeafOmnichainHolder} from "src/lz/LeafOmnichainHolder.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";

contract Tkn is ERC20 {
    constructor() ERC20("T", "T") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract LeafOmnichainHolderTest is Test {
    LeafOmnichainHolder h;
    Tkn inner;
    Tkn drop;
    address owner = address(0xA11CE);
    address adapter = address(0xADA);
    address converter = address(0xC0);
    address alice = address(0xA1);

    function setUp() public {
        vm.prank(owner);
        h = new LeafOmnichainHolder(owner);
        inner = new Tkn();
        drop = new Tkn();
        vm.startPrank(owner);
        h.setAdapter(adapter, true);
        h.setPrincipal(address(inner), true);
        h.setConverter(converter);
        vm.stopPrank();
    }

    function testAdapterReleasesPrincipal() public {
        inner.mint(address(h), 5e18);
        vm.prank(alice);
        vm.expectRevert();
        h.release(inner, alice, 1e18);
        vm.prank(adapter);
        h.release(inner, alice, 5e18);
        assertEq(inner.balanceOf(alice), 5e18);
    }

    function testSweepCannotTakePrincipal() public {
        inner.mint(address(h), 1e18);
        drop.mint(address(h), 2e18);
        vm.prank(owner);
        vm.expectRevert();
        h.sweep(inner, converter);
        vm.prank(owner);
        h.sweep(drop, converter);
        assertEq(drop.balanceOf(converter), 2e18);
    }

    function testPrincipalRotationClearsOldSweepProtection() public {
        Tkn next_ = new Tkn();
        inner.mint(address(h), 1e18);
        next_.mint(address(h), 1e18);
        vm.startPrank(owner);
        h.setPrincipal(address(next_), true);
        assertFalse(h.isPrincipal(address(inner)));
        assertTrue(h.isPrincipal(address(next_)));
        assertEq(h.principal(), address(next_));
        h.sweep(inner, converter);
        vm.expectRevert(LeafOmnichainHolder.Principal.selector);
        h.sweep(next_, converter);
        vm.stopPrank();
        assertEq(inner.balanceOf(converter), 1e18);
    }

    function testAdapterCannotReleaseSideToken() public {
        drop.mint(address(h), 3e18);
        vm.prank(adapter);
        vm.expectRevert(LeafOmnichainHolder.NotPrincipal.selector);
        h.release(drop, alice, 3e18);
        assertEq(drop.balanceOf(address(h)), 3e18);
    }

    function testHolderForbiddenSelectorsMatchFeePolicy() public {
        bytes4[11] memory blocked = [
            bytes4(0xeab52318),
            bytes4(0x38248a0c),
            bytes4(0x06866fdc),
            bytes4(0x250201db),
            bytes4(0x041d5408),
            bytes4(0x787a08a6),
            bytes4(0x42966c68),
            bytes4(0xe5c1bf6e),
            bytes4(0xd6b8546b),
            bytes4(0x55ceeb84),
            bytes4(0x40c10f19)
        ];
        vm.startPrank(owner);
        for (uint256 i; i < blocked.length; i++) {
            assertTrue(LeafForbiddenSelectors.forbidden(blocked[i]));
            vm.expectRevert(LeafOmnichainHolder.ForbiddenRewardsSelector.selector);
            h.setRewardsSelector(blocked[i]);
        }
        h.setRewardsSelector(bytes4(0x9a99b4f0));
        vm.stopPrank();
    }

    function testCannotAllowlistPrincipalAsClaim() public {
        vm.prank(owner);
        vm.expectRevert();
        h.setClaimTarget(address(inner), true);
    }
}
