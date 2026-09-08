// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafSecurity} from "src/lz/LeafSecurity.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockToken is ERC20 {
    constructor() ERC20("sKAITO", "sKAITO") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
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
    function deliver(address oapp, Origin calldata origin, bytes calldata message) external {
        LeafOFT(payable(oapp)).lzReceive(origin, bytes32(uint256(1)), message, address(this), "");
    }
    function deliverAdapter(address oapp, Origin calldata origin, bytes calldata message) external {
        LeafOFTAdapter(payable(oapp)).lzReceive(origin, bytes32(uint256(1)), message, address(this), "");
    }
}

contract LeafWrapTest is PegReady {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    MockToken token;
    LeafOFTAdapter adapter;
    LeafOFT oft;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address user = address(0xCAFE);
    uint32 constant SRC_EID = 30184;
    uint32 constant DST_EID = 30367;

    function setUp() public {
        epSrc = new MockEndpoint(SRC_EID);
        epDst = new MockEndpoint(DST_EID);
        token = new MockToken();
        vm.prank(owner);
        adapter = new LeafOFTAdapter(address(token), address(epSrc), owner, guardian, feeTo, 1_000e18);
        vm.prank(owner);
        oft = new LeafOFT("Hyperleaf sKAITO", "hKAITO", address(epDst), owner, guardian);
        vm.startPrank(owner);
        adapter.setPeer(DST_EID, address(oft));
        oft.setPeer(SRC_EID, address(adapter));
        vm.stopPrank();
        _openPair(adapter, oft, owner, 1_000e18);
        token.mint(user, 100e18);
        vm.deal(user, 1 ether);
    }

    function testLockMintsOnDeliver() public {
        vm.startPrank(user);
        token.approve(address(adapter), 10e18);
        adapter.sendTo{value: 0.01 ether}(DST_EID, user, 10e18);
        vm.stopPrank();
        bytes memory payload = _msg(oft, user, 10e18);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC_EID, sender: bytes32(uint256(uint160(address(adapter)))), nonce: 1
        });
        epDst.deliver(address(oft), origin, payload);
        assertEq(oft.balanceOf(user), 10e18);
        assertEq(adapter.totalLocked(), 10e18);
        assertEq(token.balanceOf(feeTo), 0);
    }

    function testRedeemUnlocksNoProtocolFeeOnPrincipal() public {
        testLockMintsOnDeliver();
        vm.prank(user);
        oft.sendTo{value: 0.01 ether}(SRC_EID, user, 4e18);
        bytes memory payload = _msg(adapter, user, 4e18);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: DST_EID, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1
        });
        epSrc.deliverAdapter(address(adapter), origin, payload);
        assertEq(token.balanceOf(user), 94e18);
        assertEq(adapter.totalLocked(), 6e18);
        assertEq(token.balanceOf(feeTo), 0);
    }

    function testHarvestTakesOnePercentOfYield() public {
        testLockMintsOnDeliver();
        token.mint(address(adapter), 100e18);
        adapter.harvest();
        assertEq(token.balanceOf(feeTo), 1e18);
        adapter.harvest();
        assertEq(token.balanceOf(feeTo), 1e18);
        vm.prank(user);
        oft.sendTo{value: 0.01 ether}(SRC_EID, user, 10e18);
        bytes memory payload = _msg(oft, user, 10e18);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: DST_EID, sender: bytes32(uint256(uint160(address(oft)))), nonce: 1
        });
        epSrc.deliverAdapter(address(adapter), origin, payload);
        assertEq(token.balanceOf(user), 90e18 + 109e18);
        assertEq(token.balanceOf(feeTo), 1e18);
    }

    function testGuardianPause() public {
        vm.prank(guardian);
        adapter.pause();
        vm.startPrank(user);
        token.approve(address(adapter), 1);
        vm.expectRevert();
        adapter.sendTo{value: 0.01 ether}(DST_EID, user, 1);
        vm.stopPrank();
    }

    function testOptionalDvnsSorted() public pure {
        address[] memory b = LeafSecurity.baseOptionalDvns();
        assertTrue(uint160(b[0]) < uint160(b[1]) && uint160(b[1]) < uint160(b[2]));
        address[] memory h = LeafSecurity.hyperevmOptionalDvns();
        assertTrue(uint160(h[0]) < uint160(h[1]) && uint160(h[1]) < uint160(h[2]));
    }
}
