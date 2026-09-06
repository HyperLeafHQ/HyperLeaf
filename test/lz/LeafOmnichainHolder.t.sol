// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LeafOmnichainHolder} from "src/lz/LeafOmnichainHolder.sol";

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

    function testCannotAllowlistPrincipalAsClaim() public {
        vm.prank(owner);
        vm.expectRevert();
        h.setClaimTarget(address(inner), true);
    }
}
