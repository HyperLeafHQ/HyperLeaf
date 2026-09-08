// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafCreate2} from "src/lz/LeafCreate2.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";
import {MockOrderlyProxy} from "test/mocks/MockOrderlyProxy.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LeafOrderPolicy} from "src/lz/LeafOrderPolicy.sol";
import {HypeAddresses as H} from "src/lz/HypeAddresses.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";

contract MockOft is ERC20 {
    constructor() ERC20("ORDER", "ORDER") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockUsdc is ERC20 {
    constructor() ERC20("USDC", "USDC") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30110;
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

contract LeafOmnichainCreate2Test is PegReady {
    MockEndpoint ep;
    MockOft inner;
    MockUsdc usdc;
    MockOrderlyProxy proxy;
    LeafInboundLockbox box;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address user = address(0xCAFE);

    bytes4 constant STAKE_ORDER = bytes4(keccak256("stakeOrder(uint256)"));
    bytes4 constant SEND_REQ = bytes4(keccak256("sendUserRequest(uint256,uint8)"));

    function setUp() public {
        ep = new MockEndpoint();
        inner = new MockOft();
        usdc = new MockUsdc();
        proxy = new MockOrderlyProxy(inner);
        vm.startPrank(owner);
        box = new LeafInboundLockbox(address(inner), address(ep), owner, guardian, feeTo, 1_000e18);
        box.setFarm(address(proxy), STAKE_ORDER, 0, bytes4(0));
        box.setFarmStyle(LeafInboundLockbox.FarmStyle.AmountNative, 0);
        box.setFarmRequest(SEND_REQ);
        box.setPublicRequestType(10, true);
        box.setPublicRequestType(17, true);
        box.setConverter(address(0xC0));
        box.setPeer(30367, address(1));
        vm.stopPrank();
        _openSrc(box, owner, 1_000e18);
        inner.mint(user, 100e18);
        vm.deal(user, 1 ether);
        vm.deal(address(box), 1 ether);
    }

    function testHorderIsAddressKeyed() public view {
        assertTrue(AssetCatalog.addressKeyed("horder"));
        assertFalse(AssetCatalog.addressKeyed("bluai4y"));
        AssetCatalog.Listing memory a = AssetCatalog.get("horder");
        assertEq(uint8(a.kind), uint8(AssetCatalog.Kind.Closed));
        assertEq(a.innerMainnet, 0x4E200fE2f3eFb977d5fd9c430A41531FB04d97B8);
        assertEq(a.sourceChainIdMain, 42161);
        assertEq(a.sourceEidMain, 30110);
        assertEq(a.sourceEidTest, 40231);
        assertEq(MainnetBatches.batchOf("horder"), 4);
    }

    function testHorderNotInEarlierBatches() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._requireBatch("horder", 1);
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._requireBatch("hswbera", 4);
    }

    function _requireBatch(string calldata id, uint8 batch) external pure {
        MainnetBatches.requireBatch(id, batch);
    }

    /// @dev CREATE2 would give the same lockbox on Base. We do not deploy that
    ///      twin. Opening a second source eid is the double-count bug.
    function testCreate2AddressIgnoresChainId() public view {
        bytes memory init = abi.encodePacked(
            type(LeafInboundLockbox).creationCode,
            abi.encode(address(inner), A.ENDPOINT_BSC, owner, guardian, feeTo, uint256(1_000e18))
        );
        address p = LeafCreate2.predict(LeafCreate2.LOCKBOX_SALT, init);
        assertEq(p, LeafCreate2.predict(LeafCreate2.LOCKBOX_SALT, init));
        assertTrue(p != address(0));
        // Canonical V2 endpoint is the same on Arb and Base, so the lockbox is too.
        assertEq(A.endpoint(42161), A.endpoint(8453));
        assertEq(A.endpoint(10), A.endpoint(8453));
    }

    function testStakeIsFromLockboxNoDestChain() public {
        vm.startPrank(user);
        inner.approve(address(box), 10e18);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 10e18, user);
        vm.stopPrank();
        assertEq(proxy.staked(address(box)), 10e18);
        assertEq(proxy.lastCaller(), address(box));
        assertEq(box.totalLocked(), 10e18);
        assertTrue(box.farmPrincipalOut());
        assertEq(inner.balanceOf(address(box)), 0);
    }

    function testPublicHarvestTypeAnyoneUnstakeOwnerOnly() public {
        vm.prank(user);
        box.pokeFarmRequest{value: 0}(1.156239e18, 10);
        assertEq(proxy.lastType(), 10);
        assertEq(proxy.lastCaller(), address(box));

        vm.prank(user);
        vm.expectRevert();
        box.pokeFarmRequest(1196e18, 2);

        vm.prank(owner);
        box.pokeFarmRequest(1196e18, 2);
        assertEq(proxy.lastType(), 2);
        assertEq(proxy.lastAmount(), 1196e18);
    }

    function testUsdcYieldIsNotPrincipal() public {
        usdc.mint(address(box), 1e18);
        uint256 locked = box.totalLocked();
        vm.startPrank(owner);
        box.setConvertYieldToHype(true);
        box.setHarvester(address(this));
        vm.stopPrank();
        box.pullYield(usdc, address(0xC0));
        assertEq(box.totalLocked(), locked);
        assertEq(usdc.balanceOf(address(0xC0)), 1e18);
    }

    function testBalanceIsNotSolvencyProof() public {
        vm.startPrank(user);
        inner.approve(address(box), 10e18);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 10e18, user);
        vm.stopPrank();
        assertEq(inner.balanceOf(address(box)), 0);
        assertEq(box.totalLocked(), 10e18);
        assertTrue(box.farmPrincipalOut());
        assertEq(box.ledgerPrincipal(), 0);
    }

    function testSecondMintNeedsLedgerReport() public {
        vm.startPrank(user);
        inner.approve(address(box), 20e18);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 10e18, user);
        vm.expectRevert(LeafOApp.NotHealthy.selector);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e18, user);
        vm.stopPrank();

        vm.prank(guardian);
        box.reportLedgerPrincipal(10e18);
        vm.startPrank(user);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e18, user);
        vm.stopPrank();
        assertEq(box.totalLocked(), 15e18);
    }

    function testLedgerShortfallDegrades() public {
        vm.startPrank(user);
        inner.approve(address(box), 10e18);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 10e18, user);
        vm.stopPrank();
        vm.prank(guardian);
        box.reportLedgerPrincipal(1e18);
        assertEq(uint8(box.health()), uint8(LeafOApp.Health.Degraded));
        vm.startPrank(user);
        inner.approve(address(box), 1e18);
        vm.expectRevert(LeafOApp.NotHealthy.selector);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 1e18, user);
        box.pokeFarmRequest(1, 10);
        vm.stopPrank();
        assertEq(proxy.lastType(), 10);
        vm.prank(owner);
        vm.expectRevert(LeafOApp.NotHealthy.selector);
        box.restoreHealth(LeafOApp.Health.Normal);
        vm.prank(guardian);
        box.reportLedgerPrincipal(10e18);
        vm.prank(owner);
        box.restoreHealth(LeafOApp.Health.Normal);
        assertEq(uint8(box.health()), uint8(LeafOApp.Health.Normal));
    }

    function testUserCannotInflateLedger() public {
        vm.prank(user);
        vm.expectRevert();
        box.reportLedgerPrincipal(1_000e18);
    }

    function testSelectorsMatchPins() public pure {
        assertEq(LeafOrderPolicy.STAKE_ORDER, bytes4(keccak256("stakeOrder(uint256)")));
        assertEq(LeafOrderPolicy.SEND_REQUEST, bytes4(keccak256("sendUserRequest(uint256,uint8)")));
        assertEq(STAKE_ORDER, LeafOrderPolicy.STAKE_ORDER);
        assertEq(H.ORDER_OFT, LeafOrderPolicy.ORDER_OFT);
        assertTrue(H.ORDER_ETH != H.ORDER_OFT);
        assertTrue(LeafOrderPolicy.isPublicRequestType(10));
        assertTrue(LeafOrderPolicy.isPublicRequestType(17));
        assertFalse(LeafOrderPolicy.isPublicRequestType(2));
        assertTrue(LeafOrderPolicy.isUnstakeType(4));
    }

    function testCannotMakeUnstakePublic() public {
        vm.prank(owner);
        vm.expectRevert(LeafInboundLockbox.BadStake.selector);
        box.setPublicRequestType(2, true);
    }

    function testFarmUnstakeDisabledForOrder() public {
        vm.prank(owner);
        vm.expectRevert(LeafInboundLockbox.BadStake.selector);
        box.farmUnstake(1);
    }

    function testIdleOrderIsNotYield() public {
        vm.startPrank(user);
        inner.approve(address(box), 10e18);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 10e18, user);
        vm.stopPrank();
        inner.mint(address(box), 10e18);
        vm.startPrank(owner);
        box.setConvertYieldToHype(true);
        box.setHarvester(address(this));
        vm.expectRevert();
        box.pullYield(inner, address(0xC0));
        vm.stopPrank();
        assertEq(inner.balanceOf(address(box)), 10e18);
        vm.prank(owner);
        box.acknowledgePrincipalInBox();
        assertFalse(box.farmPrincipalOut());
    }

    function testClosedOftMarketOnly() public {
        vm.prank(owner);
        LeafClosedOFT oft = new LeafClosedOFT("Hyperleaf staked ORDER", "hORDER", 0, address(ep), owner, guardian);
        assertFalse(oft.redeemEnabled());
        vm.prank(user);
        vm.expectRevert(LeafClosedOFT.ExitViaMarketOnly.selector);
        oft.send(30110, bytes32(uint256(uint160(user))), 1, user);
    }

    function testCannotAcknowledgeWithoutIdleOrder() public {
        vm.startPrank(user);
        inner.approve(address(box), 10e18);
        box.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 10e18, user);
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert(LeafInboundLockbox.InsufficientLocked.selector);
        box.acknowledgePrincipalInBox();
    }
}
