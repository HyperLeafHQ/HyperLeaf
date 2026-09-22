// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {MockConvertERC20} from "test/mocks/MockConvertERC20.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockRewardsController} from "test/mocks/MockRewardsController.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";
import {LeafUmbrellaPolicy} from "src/lz/LeafUmbrellaPolicy.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";

contract MockConvertSixDec is ERC20 {
    uint256 public assetsPerShare = 1e18;

    constructor() ERC20("stkwaUSDC", "stkwaUSDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setRate(uint256 r) external {
        assetsPerShare = r;
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return (shares * assetsPerShare) / 1e18;
    }
}

contract MockEndpointU is ILayerZeroEndpointV2 {
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

contract LeafUmbrellaTest is PegReady {
    MockEndpointU epSrc;
    MockEndpointU epDst;
    MockConvertERC20 inner;
    MockERC20 gho;
    MockRewardsController controller;
    LeafOFTAdapter adapter;
    LeafOFT oft;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address converter = address(0xC0DE);
    address user = address(0xCAFE);
    uint32 constant SRC = 30101;
    uint32 constant DST = 30367;
    uint64 nonce;

    function setUp() public {
        epSrc = new MockEndpointU();
        epDst = new MockEndpointU();
        inner = new MockConvertERC20("stkwaUSDC", "stkwaUSDC");
        gho = new MockERC20("GHO", "GHO");
        controller = new MockRewardsController(gho);
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(epSrc), owner, guardian, feeTo, 1_000e18);
        oft = new LeafOFT("hstkwaUSDC", "hstkwaUSDC", address(epDst), owner, guardian);
        adapter.setPeer(DST, address(oft));
        oft.setPeer(SRC, address(adapter));
        adapter.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
        adapter.setRetainRateYield(true);
        adapter.setConvertYieldToHype(true);
        adapter.setConverter(converter);
        adapter.setHarvester(owner);
        adapter.setRewardsTarget(address(controller));
        adapter.setRewardsSelector(bytes4(0xbb492bf5));
        vm.stopPrank();
        _openPair(adapter, oft, owner, 1_000e18);
        inner.mint(user, 200e18);
        vm.deal(user, 1 ether);
    }

    function _mintLeaf(uint256 assets) internal {
        vm.startPrank(user);
        inner.approve(address(adapter), assets);
        adapter.sendTo{value: 0.01 ether}(DST, user, assets);
        vm.stopPrank();
        uint256 shares = adapter.totalLocked();
        bytes memory payload = _msg(oft, user, assets);
        nonce += 1;
        ILayerZeroEndpointV2.Origin memory oIn = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(adapter)))), nonce: nonce
        });
        vm.prank(address(epDst));
        oft.lzReceive(oIn, bytes32(uint256(nonce)), payload, address(0), "");
        shares;
    }

    function testClaimAllRewardsDoesNotMoveStk() public {
        _mintLeaf(100e18);
        controller.seed(address(adapter), 5e18);
        uint256 stk = inner.balanceOf(address(adapter));
        adapter.pokeRewards();
        assertEq(inner.balanceOf(address(adapter)), stk);
        assertEq(gho.balanceOf(address(adapter)), 5e18);
        vm.prank(owner);
        adapter.pullYield(gho, converter);
        assertEq(gho.balanceOf(converter), 5e18);
        assertEq(gho.balanceOf(address(adapter)), 0);
    }

    function testRateSkimStillOnePercent() public {
        _mintLeaf(100e18);
        inner.setRate(11e17);
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        uint256 add = (100e18 * (uint256(11e17) - 1e18)) / uint256(11e17);
        assertEq(inner.balanceOf(converter), add / 100);
        assertEq(adapter.totalLocked(), 100e18);
    }

    function testCannotPointClaimAllAtInner() public {
        _mintLeaf(1e18);
        vm.prank(owner);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        adapter.setRewardsTarget(address(inner));

        LeafOFTAdapter fresh = new LeafOFTAdapter(address(inner), address(epSrc), owner, guardian, feeTo, 1_000e18);
        vm.startPrank(owner);
        fresh.setRewardsTarget(address(inner));
        fresh.setRewardsSelector(bytes4(0xbb492bf5));
        vm.expectRevert(LeafYieldFee.BadRewardsTarget.selector);
        fresh.pokeRewards();
        vm.stopPrank();
    }

    function testSquidPokeRejectedWhileControllerTargetSet() public {
        vm.prank(owner);
        adapter.setRewardsSelector(bytes4(0x9a99b4f0));
        vm.expectRevert(LeafYieldFee.BadRewardsTarget.selector);
        adapter.pokeRewards();
    }

    function testUmbrellaPins() public view {
        AssetCatalog.Listing memory a = AssetCatalog.get("hstkwausdc");
        assertEq(a.innerMainnet, LeafUmbrellaPolicy.STKWA_USDC);
        assertEq(a.sourceChainIdMain, 1);
        assertEq(MainnetBatches.batchOf("hstkwausdc"), 3);
        assertEq(LeafUmbrellaPolicy.REWARDS_CONTROLLER, 0x4655Ce3D625a63d30bA704087E52B4C31E38188B);
        assertEq(LeafUmbrellaPolicy.CLAIM_ALL_REWARDS, bytes4(0xbb492bf5));
        assertEq(adapter.CLAIM_ALL_REWARDS(), bytes4(0xbb492bf5));
        assertEq(LeafUmbrellaPolicy.MAX_RATE_JUMP_BPS, 300);
        assertEq(LeafUmbrellaPolicy.SHARE_SCALE, 1e12);
        assertEq(LeafUmbrellaPolicy.INNER_DECIMALS, 6);
        assertEq(LeafUmbrellaPolicy.shareScaleOf("hstkwausdc"), 1e12);
        assertEq(LeafUmbrellaPolicy.shareScaleOf("hcbeth"), 1);
    }

    function testUmbrellaRejectsWrongInnerOrController() public {
        LeafUmbrellaPolicy.requireStkwaUsdc(LeafUmbrellaPolicy.STKWA_USDC);
        LeafUmbrellaPolicy.requireController(LeafUmbrellaPolicy.REWARDS_CONTROLLER, LeafUmbrellaPolicy.STKWA_USDC);
        vm.expectRevert(LeafUmbrellaPolicy.NotStkwaUsdc.selector);
        this._requireInner(LeafUmbrellaPolicy.WA_ETH_USDC);
        vm.expectRevert(LeafUmbrellaPolicy.NotStkwaUsdc.selector);
        this._requireInner(address(inner));
        vm.expectRevert(LeafUmbrellaPolicy.BadUmbrellaController.selector);
        this._requireCtrl(address(0), LeafUmbrellaPolicy.STKWA_USDC);
        vm.expectRevert(LeafUmbrellaPolicy.BadUmbrellaController.selector);
        this._requireCtrl(LeafUmbrellaPolicy.STKWA_USDC, LeafUmbrellaPolicy.STKWA_USDC);
    }

    function testUmbrellaExitSelectorsForbidden() public pure {
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x787a08a6)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0x250201db)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xba087652)));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xb460af94)));
        assertFalse(LeafForbiddenSelectors.forbidden(bytes4(0xbb492bf5)));
    }

    function testUmbrellaJumpBreakerPinnedAt300() public {
        vm.prank(owner);
        adapter.setMaxRateJumpBps(300);
        assertEq(adapter.maxRateJumpBps(), 300);
        _mintLeaf(100e18);
        inner.setRate(1.02e18);
        vm.prank(owner);
        adapter.pullYield(inner, converter);
        uint256 add = (100e18 * (uint256(1.02e18) - 1e18)) / uint256(1.02e18);
        assertEq(inner.balanceOf(converter), add / 100);
        inner.setRate(1.10e18);
        vm.prank(owner);
        vm.expectRevert(LeafYieldFee.NoYield.selector);
        adapter.pullYield(inner, converter);
    }

    function testSixDecRoundTripAndScaleFreeze() public {
        MockConvertSixDec stk = new MockConvertSixDec();
        assertEq(IERC20Metadata(address(stk)).decimals(), 6);
        vm.startPrank(owner);
        LeafOFTAdapter box = new LeafOFTAdapter(address(stk), address(epSrc), owner, guardian, feeTo, 0);
        LeafOFT dest = new LeafOFT("hstkwaUSDC", "hstkwaUSDC", address(epDst), owner, guardian);
        box.setPeer(DST, address(dest));
        dest.setPeer(SRC, address(box));
        box.setShareScale(LeafUmbrellaPolicy.SHARE_SCALE);
        box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
        box.setRetainRateYield(true);
        box.setMaxRateJumpBps(300);
        box.setConvertYieldToHype(true);
        box.setConverter(converter);
        box.setHarvester(owner);
        vm.stopPrank();
        _openPair(box, dest, owner, 1_000e18);
        assertEq(box.shareScale(), 1e12);
        stk.mint(user, 2e6);
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        stk.approve(address(box), 1e6);
        box.sendTo{value: 0.01 ether}(DST, user, 1e6);
        vm.stopPrank();
        assertEq(box.totalLocked(), 1e18);
        assertEq(stk.balanceOf(address(box)), 1e6);

        bytes memory payload = _msg(dest, user, 1e18);
        nonce += 1;
        ILayerZeroEndpointV2.Origin memory oIn = ILayerZeroEndpointV2.Origin({
            srcEid: SRC, sender: bytes32(uint256(uint160(address(box)))), nonce: nonce
        });
        vm.prank(address(epDst));
        dest.lzReceive(oIn, bytes32(uint256(nonce)), payload, address(0), "");
        assertEq(dest.balanceOf(user), 1e18);
        assertEq(dest.decimals(), 18);

        vm.startPrank(owner);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        box.setShareScale(1);
        vm.stopPrank();

        vm.startPrank(user);
        dest.sendTo{value: 0.01 ether}(SRC, user, 1e18);
        vm.stopPrank();
        bytes memory back = _msg(box, user, 1e18);
        nonce += 1;
        ILayerZeroEndpointV2.Origin memory oOut = ILayerZeroEndpointV2.Origin({
            srcEid: DST, sender: bytes32(uint256(uint160(address(dest)))), nonce: nonce
        });
        vm.prank(address(epSrc));
        box.lzReceive(oOut, bytes32(uint256(nonce)), back, address(0), "");
        assertEq(stk.balanceOf(user), 2e6);
        assertEq(box.totalLocked(), 0);
        assertEq(dest.balanceOf(user), 0);
    }

    function testSixDecRateSkimAndJumpOnRawInner() public {
        MockConvertSixDec stk = new MockConvertSixDec();
        vm.startPrank(owner);
        LeafOFTAdapter box = new LeafOFTAdapter(address(stk), address(epSrc), owner, guardian, feeTo, 0);
        LeafOFT dest = new LeafOFT("hstkwaUSDC", "hstkwaUSDC", address(epDst), owner, guardian);
        box.setPeer(DST, address(dest));
        dest.setPeer(SRC, address(box));
        box.setShareScale(LeafUmbrellaPolicy.SHARE_SCALE);
        box.setRateKind(LeafYieldFee.RateKind.ConvertToAssets);
        box.setRetainRateYield(true);
        box.setMaxRateJumpBps(300);
        box.setConvertYieldToHype(true);
        box.setConverter(converter);
        box.setHarvester(owner);
        vm.stopPrank();
        _openPair(box, dest, owner, 1_000e18);
        stk.mint(user, 1e6);
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        stk.approve(address(box), 1e6);
        box.sendTo{value: 0.01 ether}(DST, user, 1e6);
        vm.stopPrank();

        stk.setRate(1.02e18);
        vm.prank(owner);
        box.pullYield(stk, converter);
        uint256 add = (uint256(1e6) * (uint256(1.02e18) - 1e18)) / uint256(1.02e18);
        assertEq(stk.balanceOf(converter), add / 100);
        assertEq(box.totalLocked(), 1e18);

        stk.setRate(1.10e18);
        vm.prank(owner);
        vm.expectRevert(LeafYieldFee.NoYield.selector);
        box.pullYield(stk, converter);
    }

    function _requireInner(address inner_) external pure {
        LeafUmbrellaPolicy.requireStkwaUsdc(inner_);
    }

    function _requireCtrl(address c, address inner_) external pure {
        LeafUmbrellaPolicy.requireController(c, inner_);
    }
}
