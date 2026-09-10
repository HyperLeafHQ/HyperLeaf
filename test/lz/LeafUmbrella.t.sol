// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {MockConvertERC20} from "test/mocks/MockConvertERC20.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockRewardsController} from "test/mocks/MockRewardsController.sol";
import {LeafUmbrellaPolicy} from "src/lz/LeafUmbrellaPolicy.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

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

    function testUmbrellaPins() public pure {
        AssetCatalog.Listing memory a = AssetCatalog.get("hstkwausdc");
        assertEq(a.innerMainnet, LeafUmbrellaPolicy.STKWA_ETH_USDC_V1);
        assertEq(a.defaultCap, 0);
        LeafUmbrellaPolicy.requireStkwaUsdc(LeafUmbrellaPolicy.STKWA_ETH_USDC_V1);
        LeafUmbrellaPolicy.requireController(LeafUmbrellaPolicy.REWARDS_CONTROLLER);
        assertEq(LeafUmbrellaPolicy.CLAIM_ALL_REWARDS, bytes4(0xbb492bf5));
    }
}
