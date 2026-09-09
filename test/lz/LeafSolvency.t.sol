// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockToken is ERC20 {
    constructor() ERC20("xSQUID", "xSQUID") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 1;
    }
    function send(MessagingParams calldata p, address) external payable returns (MessagingReceipt memory r) {
        r.guid = keccak256(abi.encode(p, block.number));
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

/// @dev hxSQUID/hKAITO/hcbETH core invariant:
///      oft.totalSupply() ≤ adapter.totalLocked() ≤ depositCap
contract LeafSolvencyTest is PegReady {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    MockToken inner;
    LeafOFTAdapter adapter;
    LeafOFT oft;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address user = address(0xCAFE);
    uint32 constant SRC = 30184;
    uint32 constant DST = 30367;

    function setUp() public {
        epSrc = new MockEndpoint();
        epDst = new MockEndpoint();
        inner = new MockToken();
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(epSrc), owner, guardian, feeTo, 1_000e18);
        oft = new LeafOFT("hxSQUID", "hxSQUID", address(epDst), owner, guardian);
        adapter.setPeer(DST, address(oft));
        oft.setPeer(SRC, address(adapter));
        adapter.setConvertYieldToHype(true);
        vm.stopPrank();
        _openPair(adapter, oft, owner, 1_000e18);
        inner.mint(user, 100e18);
        vm.deal(user, 1 ether);
    }

    function _invariant() internal view {
        assertLe(oft.totalSupply(), adapter.totalLocked());
        assertLe(adapter.totalLocked(), adapter.depositCap());
        assertLe(oft.totalSupply(), oft.supplyCap());
    }

    function _deliverMint(address to, uint256 amount) internal {
        bytes memory payload = _msg(oft, to, amount);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(adapter)))), nonce: 1
        });
        vm.prank(address(epDst));
        oft.lzReceive(origin, bytes32(uint256(1)), payload, address(0), "");
    }

    function _deliverRedeem(address to, uint256 amount) internal {
        bytes memory payload = _msg(adapter, to, amount);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: DST, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1
        });
        vm.prank(address(epSrc));
        adapter.lzReceive(origin, bytes32(uint256(2)), payload, address(0), "");
    }

    function testMintKeepsSupplyLeLocked() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        _deliverMint(user, 10e18);
        _invariant();
        assertEq(oft.totalSupply(), 10e18);
        assertEq(adapter.totalLocked(), 10e18);
    }

    function testDonationDoesNotMint() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        _deliverMint(user, 10e18);
        inner.mint(address(adapter), 50e18);
        assertEq(adapter.totalLocked(), 10e18);
        _invariant();
    }

    function testBurnKeepsSupplyLeLocked() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        _deliverMint(user, 10e18);
        vm.prank(user);
        oft.sendTo{value: 0.01 ether}(SRC, user, 4e18);
        _deliverRedeem(user, 4e18);
        _invariant();
        assertEq(oft.totalSupply(), 6e18);
        assertEq(adapter.totalLocked(), 6e18);
        assertEq(inner.balanceOf(user), 94e18);
    }

    function testTransferDoesNotChangeSupply() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        _deliverMint(user, 10e18);
        address bob = address(0xB0B0);
        vm.prank(user);
        oft.transfer(bob, 3e18);
        _invariant();
        assertEq(oft.totalSupply(), 10e18);
        assertEq(oft.balanceOf(bob), 3e18);
    }

    function testUnexpectedInnerIsNotBacking() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST, user, 10e18);
        vm.stopPrank();
        _deliverMint(user, 10e18);
        inner.mint(address(adapter), 100e18);
        adapter.harvest();
        assertEq(adapter.totalLocked(), 10e18);
        _invariant();
    }
}
