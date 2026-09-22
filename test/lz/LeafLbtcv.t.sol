// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {LeafLbtcvPolicy} from "src/lz/LeafLbtcvPolicy.sol";
import {LeafLbtcPolicy} from "src/lz/LeafLbtcPolicy.sol";
import {LeafUmbrellaPolicy} from "src/lz/LeafUmbrellaPolicy.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockLbtcv8Dec is ERC20 {
    constructor() ERC20("LBTCv", "LBTCv") {}

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockVedaAccountant {
    address public immutable quote;
    uint256 public wbtcRate = 9e8;
    uint256 public lbtcRate = 1.02e8;

    constructor(address quote_) {
        quote = quote_;
    }

    function getRate() external view returns (uint256) {
        return wbtcRate;
    }

    function getRateInQuote(address q) external view returns (uint256) {
        require(q == quote, "quote");
        return lbtcRate;
    }

    function setLbtcRate(uint256 r) external {
        lbtcRate = r;
    }
}

contract MockEndpointLbtcv is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30101;
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

contract LeafLbtcvTest is PegReady {
    MockEndpointLbtcv ep;
    MockLbtcv8Dec inner;
    MockVedaAccountant accountant;
    LeafOFTAdapter adapter;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address converter = address(0xC0DE);
    address user = address(0xCAFE);

    function setUp() public {
        ep = new MockEndpointLbtcv();
        inner = new MockLbtcv8Dec();
        accountant = new MockVedaAccountant(LeafLbtcvPolicy.LBTC);
        vm.startPrank(owner);
        adapter = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, feeTo, 0);
        adapter.setConverter(converter);
        adapter.setRewardsTarget(address(accountant));
        adapter.setRateQuote(LeafLbtcvPolicy.LBTC);
        adapter.setShareScale(LeafLbtcvPolicy.SHARE_SCALE);
        adapter.setMaxRateJumpBps(LeafLbtcvPolicy.MAX_RATE_JUMP_BPS);
        adapter.setRateKind(LeafYieldFee.RateKind.GetRateInQuote);
        adapter.setRetainRateYield(true);
        adapter.setConvertYieldToHype(true);
        adapter.setPeer(30367, address(1));
        vm.stopPrank();
        _openSrc(adapter, owner, 0);
        inner.mint(user, 2e8);
        vm.deal(user, 1 ether);
    }

    function testCatalogPins() public view {
        AssetCatalog.Listing memory a = AssetCatalog.get("hlbtcv");
        assertEq(a.innerMainnet, LeafLbtcvPolicy.LBTCV);
        assertTrue(a.innerMainnet != LeafLbtcvPolicy.LBTC);
        assertTrue(a.innerMainnet != LeafLbtcvPolicy.WBTC);
        assertTrue(a.innerMainnet != LeafLbtcvPolicy.CBBTC);
        assertTrue(AssetCatalog.get("hlbtc").productionEvm == false);
        assertEq(a.defaultCap, 0);
        assertEq(LeafLbtcvPolicy.shareScaleOf("hlbtcv"), 1e10);
        assertEq(LeafLbtcPolicy.shareScaleOf("hlbtcv"), 1);
        assertEq(LeafUmbrellaPolicy.shareScaleOf("hlbtcv"), 1);
        assertEq(a.sourceChainIdMain, 1);
        assertEq(MainnetBatches.batchOf("hlbtcv"), 3);
        assertEq(LeafLbtcvPolicy.INNER_DECIMALS, 8);
        assertEq(LeafLbtcvPolicy.ACCOUNTANT, 0x28634D0c5edC67CF2450E74deA49B90a4FF93dCE);
    }

    function testRequireLbtcvRejectsCousins() public {
        vm.expectRevert(LeafLbtcvPolicy.NotLbtcv.selector);
        this._require(LeafLbtcvPolicy.LBTC);
        vm.expectRevert(LeafLbtcvPolicy.NotLbtcv.selector);
        this._require(LeafLbtcvPolicy.WBTC);
        vm.expectRevert(LeafLbtcvPolicy.NotLbtcv.selector);
        this._require(LeafLbtcvPolicy.CBBTC);
        vm.expectRevert(LeafLbtcvPolicy.NotLbtcv.selector);
        this._require(LeafLbtcvPolicy.BTCB);
        LeafLbtcvPolicy.requireLbtcv(LeafLbtcvPolicy.LBTCV);
        LeafLbtcvPolicy.requireAccountant(LeafLbtcvPolicy.ACCOUNTANT);
        LeafLbtcvPolicy.requireQuote(LeafLbtcvPolicy.LBTC);
        vm.expectRevert(LeafLbtcvPolicy.BadLbtcvQuote.selector);
        this._requireQuote(LeafLbtcvPolicy.WBTC);
    }

    function _require(address inner_) external pure {
        LeafLbtcvPolicy.requireLbtcv(inner_);
    }

    function _requireQuote(address q) external pure {
        LeafLbtcvPolicy.requireQuote(q);
    }

    function testRateReadsLbtcQuoteNotWbtcGetRate() public view {
        assertEq(accountant.getRate(), 9e8);
        assertEq(accountant.getRateInQuote(LeafLbtcvPolicy.LBTC), 1.02e8);
        assertEq(adapter.lastRate(), 1.02e8);
        assertEq(uint8(adapter.rateKind()), uint8(LeafYieldFee.RateKind.GetRateInQuote));
        assertEq(adapter.rateQuote(), LeafLbtcvPolicy.LBTC);
    }

    function testZeroQuoteOrTokenTargetReverts() public {
        vm.startPrank(owner);
        LeafOFTAdapter box = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, feeTo, 0);
        box.setRewardsTarget(address(accountant));
        vm.expectRevert(LeafYieldFee.BadRateFeed.selector);
        box.setRateKind(LeafYieldFee.RateKind.GetRateInQuote);
        box.setRateQuote(address(inner));
        vm.expectRevert(LeafYieldFee.BadRateFeed.selector);
        box.setRateKind(LeafYieldFee.RateKind.GetRateInQuote);
        vm.stopPrank();
    }

    function testEightDecRoundTrip() public {
        MockEndpointLbtcv epDst = new MockEndpointLbtcv();
        vm.startPrank(owner);
        LeafOFTAdapter box = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, feeTo, 0);
        LeafOFT dest = new LeafOFT("hLBTCv", "hLBTCv", address(epDst), owner, guardian);
        box.setPeer(30367, address(dest));
        dest.setPeer(30101, address(box));
        box.setConverter(converter);
        box.setRewardsTarget(address(accountant));
        box.setRateQuote(LeafLbtcvPolicy.LBTC);
        box.setShareScale(LeafLbtcvPolicy.SHARE_SCALE);
        box.setMaxRateJumpBps(LeafLbtcvPolicy.MAX_RATE_JUMP_BPS);
        box.setRateKind(LeafYieldFee.RateKind.GetRateInQuote);
        box.setRetainRateYield(true);
        box.setConvertYieldToHype(true);
        vm.stopPrank();
        _openPair(box, dest, owner, 1_000e18);
        assertEq(IERC20Metadata(address(inner)).decimals(), 8);

        vm.startPrank(user);
        inner.approve(address(box), 1e8);
        box.sendTo{value: 0.01 ether}(30367, user, 1e8);
        vm.stopPrank();
        assertEq(box.totalLocked(), 1e18);
        assertEq(inner.balanceOf(address(box)), 1e8);

        bytes memory payload = _msg(dest, user, 1e18);
        ILayerZeroEndpointV2.Origin memory oIn = ILayerZeroEndpointV2.Origin({
            srcEid: 30101, sender: bytes32(uint256(uint160(address(box)))), nonce: 1
        });
        vm.prank(address(epDst));
        dest.lzReceive(oIn, bytes32(uint256(1)), payload, address(0), "");
        assertEq(dest.balanceOf(user), 1e18);

        vm.startPrank(owner);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        box.setShareScale(1);
        vm.expectRevert(LeafOApp.ConfigFrozen.selector);
        box.setRateQuote(address(1));
        vm.stopPrank();

        vm.startPrank(user);
        dest.sendTo{value: 0.01 ether}(30101, user, 1e18);
        vm.stopPrank();
        bytes memory back = _msg(box, user, 1e18);
        ILayerZeroEndpointV2.Origin memory oOut = ILayerZeroEndpointV2.Origin({
            srcEid: 30367, sender: bytes32(uint256(uint160(address(dest)))), nonce: 1
        });
        vm.prank(address(ep));
        box.lzReceive(oOut, bytes32(uint256(1)), back, address(0), "");
        assertEq(inner.balanceOf(user), 2e8);
        assertEq(box.totalLocked(), 0);
    }

    function testVedaExitSelectorsForbidden() public {
        vm.startPrank(owner);
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0xb5c5f672));
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0xd0d0e108));
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0x09bae891));
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        adapter.setRewardsSelector(bytes4(0x0efe6a8b));
        assertTrue(LeafForbiddenSelectors.forbidden(bytes4(0xb5c5f672)));
        vm.stopPrank();
    }

    function testJumpBreakerPinnedAt300() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 1e8);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
        accountant.setLbtcRate(1.0404e8); // +2% of 1.02e8
        adapter.pokeRate();
        assertFalse(adapter.rateJumped());
        accountant.setLbtcRate(1.122e8); // +10%
        adapter.pokeRate();
        assertTrue(adapter.rateJumped());
        vm.startPrank(user);
        inner.approve(address(adapter), 5e6);
        vm.expectRevert(LeafOApp.NotHealthy.selector);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
    }

    function testSmallRateBumpSkimsOnePercent() public {
        vm.startPrank(user);
        inner.approve(address(adapter), 5e6);
        adapter.send{value: 0.01 ether}(30367, bytes32(uint256(uint160(user))), 5e6, user);
        vm.stopPrank();
        // 1.02e8 * 1.01 = 1.0302e8
        accountant.setLbtcRate(1.0302e8);
        uint256 before = inner.balanceOf(converter);
        adapter.pullYield(inner, converter);
        uint256 add = (uint256(5e6) * (1.0302e8 - 1.02e8)) / 1.0302e8;
        assertEq(inner.balanceOf(converter) - before, add / 100);
    }
}
