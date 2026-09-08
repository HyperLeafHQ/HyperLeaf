// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafHypeRewarder} from "src/lz/LeafHypeRewarder.sol";
import {LeafYieldConverter} from "src/lz/LeafYieldConverter.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n) ERC20(n, n) {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    uint32 public eid;
    constructor(uint32 eid_) {
        eid = eid_;
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

/// @dev DEX or bridge. `payOut` = 0 + `bridge` = true sends tokenIn to 0xDEAD.
contract MockRoute {
    IERC20 public inT;
    IERC20 public outT;
    uint256 public payOut;
    bool public fail;
    bool public bridge;

    constructor(IERC20 inT_, IERC20 outT_) {
        inT = inT_;
        outT = outT_;
    }

    function setPay(uint256 n) external {
        payOut = n;
    }

    function setFail(bool v) external {
        fail = v;
    }

    function setBridge(bool v) external {
        bridge = v;
    }

    function run(uint256 amountIn) external {
        if (fail) revert("no liq");
        if (bridge) {
            inT.transferFrom(msg.sender, address(0xDEAD), amountIn);
            return;
        }
        inT.transferFrom(msg.sender, address(this), amountIn);
        if (payOut > 0) outT.transfer(msg.sender, payOut);
    }
}

contract LeafYieldConverterTest is PegReady {
    MockEndpoint epSrc;
    MockEndpoint epDst;
    MockERC20 quid;
    MockERC20 usdc;
    MockERC20 whype;
    MockERC20 inner;
    LeafOFTAdapter adapter;
    LeafOFT oft;
    LeafHypeRewarder rewarder;
    LeafYieldConverter conv;
    MockRoute aero;
    MockRoute debridge;
    MockRoute mayan;

    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address keeper = address(0x1111);
    address feeTo = address(0xFEE);
    address alice = address(0xA1);
    bytes32 constant ID = keccak256("hxsquid");
    uint32 constant DST = 30367;
    uint32 constant SRC = 30184;

    function setUp() public {
        epSrc = new MockEndpoint(SRC);
        epDst = new MockEndpoint(DST);
        inner = new MockERC20("xSQUID");
        quid = new MockERC20("QUID");
        usdc = new MockERC20("USDC");
        whype = new MockERC20("WHYPE");
        aero = new MockRoute(quid, whype);
        debridge = new MockRoute(quid, usdc);
        mayan = new MockRoute(usdc, IERC20(address(0)));
        mayan.setBridge(true);

        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(epSrc), owner, guardian, feeTo, 10_000e18);
        oft = new LeafOFT("hxSQUID", "hxSQUID", address(epDst), owner, guardian);
        rewarder = new LeafHypeRewarder(address(whype), owner, feeTo);
        conv = new LeafYieldConverter(owner, keeper, guardian);
        oft.setHypeRewarder(address(rewarder), ID);
        rewarder.register(ID, address(oft));
        conv.setLockbox(address(adapter), true);
        conv.setToken(address(quid), true);
        conv.setOutput(address(whype), true);
        conv.setOutput(address(usdc), true);
        conv.setRoute(address(aero), true);
        conv.setRoute(address(debridge), true);
        conv.setRoute(address(mayan), true);
        conv.setRewarder(address(rewarder), address(whype));
        conv.setMinPrice(address(quid), address(whype), 8e17);
        conv.setMinPrice(address(quid), address(usdc), 9e17);
        adapter.setHarvester(keeper);
        adapter.setConverter(address(conv));
        adapter.setConvertYieldToHype(true);
        adapter.setPeer(DST, address(oft));
        oft.setPeer(SRC, address(adapter));
        vm.stopPrank();
        _openPair(adapter, oft, owner, 10_000e18);
        inner.mint(alice, 100e18);
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        inner.approve(address(adapter), 100e18);
        vm.prank(alice);
        adapter.send{value: 0.01 ether}(DST, bytes32(uint256(uint160(alice))), 100e18, alice);
        _deliver(alice, 100e18);
    }

    uint64 lzNonce = 1;

    function _deliver(address to, uint256 amount) internal {
        bytes memory payload = _msg(oft, to, amount);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: SRC,
            sender: bytes32(uint256(uint160(address(adapter)))),
            nonce: lzNonce
        });
        unchecked {
            ++lzNonce;
        }
        vm.prank(address(epDst));
        oft.lzReceive(origin, bytes32(uint256(lzNonce)), payload, address(0), "");
    }

    function _pullQuid(uint256 n) internal {
        quid.mint(address(adapter), n);
        vm.prank(alice);
        adapter.pullYield(IERC20(address(quid)), address(conv));
    }

    function _exec(IERC20 tin, uint256 amt, IERC20 tout, uint256 minOut, address route, uint256 routeAmt) internal {
        vm.prank(keeper);
        conv.execute(tin, amt, tout, minOut, route, abi.encodeCall(MockRoute.run, (routeAmt)), block.timestamp + 1);
    }

    function testPullLandsInConverterNotEoa() public {
        _pullQuid(50e18);
        assertEq(quid.balanceOf(address(conv)), 50e18);
        assertEq(quid.balanceOf(keeper), 0);
    }

    function testSwapMinOut() public {
        _pullQuid(50e18);
        whype.mint(address(aero), 40e18);
        aero.setPay(40e18);
        _exec(IERC20(address(quid)), 50e18, IERC20(address(whype)), 40e18, address(aero), 50e18);
        assertEq(whype.balanceOf(address(conv)), 40e18);
        assertEq(quid.balanceOf(address(conv)), 0);
    }

    function testSwapBelowMinOutRevertsAndKeepsInventory() public {
        _pullQuid(50e18);
        whype.mint(address(aero), 1e18);
        aero.setPay(1e18);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(LeafYieldConverter.BelowMinOut.selector, 1e18, 40e18));
        conv.execute(
            IERC20(address(quid)), 50e18, IERC20(address(whype)), 40e18, address(aero), abi.encodeCall(MockRoute.run, (50e18)), block.timestamp + 1
        );
        assertEq(quid.balanceOf(address(conv)), 50e18);
    }

    function testRouteFailThenFallback() public {
        _pullQuid(50e18);
        aero.setFail(true);
        vm.prank(keeper);
        vm.expectRevert(LeafYieldConverter.RouteFailed.selector);
        conv.execute(
            IERC20(address(quid)),
            50e18,
            IERC20(address(whype)),
            40e18,
            address(aero),
            abi.encodeCall(MockRoute.run, (50e18)),
            block.timestamp + 1
        );
        assertEq(quid.balanceOf(address(conv)), 50e18);

        usdc.mint(address(debridge), 45e18);
        debridge.setPay(45e18);
        _exec(IERC20(address(quid)), 50e18, IERC20(address(usdc)), 45e18, address(debridge), 50e18);
        assertEq(usdc.balanceOf(address(conv)), 45e18);

        _exec(IERC20(address(usdc)), 45e18, IERC20(address(0)), 0, address(mayan), 45e18);
        assertEq(usdc.balanceOf(address(conv)), 0);
        assertEq(usdc.balanceOf(address(0xDEAD)), 45e18);
    }

    function testHaltStopsPullAndExecute() public {
        _pullQuid(10e18);
        address[] memory boxes = new address[](1);
        boxes[0] = address(adapter);
        vm.prank(keeper);
        conv.halt(boxes);
        assertFalse(adapter.convertYieldToHype());

        quid.mint(address(adapter), 5e18);
        vm.prank(keeper);
        vm.expectRevert(LeafYieldFee.ConvertHalted.selector);
        adapter.pullYield(IERC20(address(quid)), address(conv));

        vm.prank(keeper);
        vm.expectRevert(LeafYieldConverter.HaltedErr.selector);
        conv.execute(
            IERC20(address(quid)),
            10e18,
            IERC20(address(whype)),
            8e18,
            address(aero),
            abi.encodeCall(MockRoute.run, (10e18)),
            block.timestamp + 1
        );
    }

    function testReturnOnlyToLockbox() public {
        _pullQuid(10e18);
        vm.prank(keeper);
        vm.expectRevert(LeafYieldConverter.BadLockbox.selector);
        conv.returnToLockbox(keeper, IERC20(address(quid)), 10e18);

        vm.prank(keeper);
        conv.returnToLockbox(address(adapter), IERC20(address(quid)), 10e18);
        assertEq(quid.balanceOf(address(adapter)), 10e18);
    }

    function testNotifyCannotExceedBalanceOrMin() public {
        whype.mint(address(conv), 10e18);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(LeafYieldConverter.BelowMinOut.selector, 5e18, 9e18));
        conv.notify(ID, 5e18, 9e18);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(LeafYieldConverter.BelowMinOut.selector, 11e18, 10e18));
        conv.notify(ID, 11e18, 11e18);

        vm.prank(keeper);
        conv.notify(ID, 10e18, 10e18);
        assertEq(whype.balanceOf(feeTo), 0.1e18);
    }

    function testWrapStillWorksWhenConvertHalted() public {
        address[] memory boxes = new address[](1);
        boxes[0] = address(adapter);
        vm.prank(guardian);
        conv.halt(boxes);
        inner.mint(alice, 1e18);
        vm.prank(alice);
        inner.approve(address(adapter), 1e18);
        vm.prank(alice);
        adapter.send{value: 0.01 ether}(DST, bytes32(uint256(uint160(alice))), 1e18, alice);
        _deliver(alice, 1e18);
        assertEq(oft.balanceOf(alice), 101e18);
        assertEq(adapter.totalLocked(), 101e18);
    }

    function testUnknownRouteReverts() public {
        _pullQuid(1e18);
        vm.prank(keeper);
        vm.expectRevert(LeafYieldConverter.BadRoute.selector);
        conv.execute(IERC20(address(quid)), 1e18, IERC20(address(whype)), 1, address(0xBEEF), "", block.timestamp + 1);
    }

    function testDustMinOutCannotSandwich() public {
        _pullQuid(50e18);
        uint256 req = conv.requiredMinOut(address(quid), address(whype), 50e18);
        assertEq(req, 40e18);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(LeafYieldConverter.BelowMinOut.selector, 0, req));
        conv.execute(
            IERC20(address(quid)), 50e18, IERC20(address(whype)), 1, address(aero), abi.encodeCall(MockRoute.run, (50e18)), block.timestamp + 1
        );
        assertEq(quid.balanceOf(address(conv)), 50e18);
    }

    function testExpiredDeadlineReverts() public {
        _pullQuid(1e18);
        vm.prank(keeper);
        vm.expectRevert(LeafYieldConverter.Expired.selector);
        conv.execute(
            IERC20(address(quid)), 1e18, IERC20(address(whype)), 8e17, address(aero), abi.encodeCall(MockRoute.run, (1e18)), block.timestamp - 1
        );
    }
}
