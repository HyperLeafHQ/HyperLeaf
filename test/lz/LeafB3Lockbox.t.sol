// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PegReady} from "test/lz/PegReady.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LeafB3Lockbox} from "src/lz/LeafB3Lockbox.sol";
import {LeafB3Policy as P} from "src/lz/LeafB3Policy.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockB3 is ERC20 {
    constructor() ERC20("B3", "B3") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockWinClaim {
    IERC20 public token;
    uint256 public lastIndex;
    constructor(IERC20 token_) {
        token = token_;
    }
    function claimDelayedWithdrawal(uint256 index) external {
        lastIndex = index;
        require(token.transfer(msg.sender, 10 ether), "pay");
    }
}

contract MockStake {
    IERC20 public token;
    address public custody;
    address public lastUser;
    constructor(IERC20 token_, address custody_) {
        token = token_;
        custody = custody_;
    }
    function stakeFor(address user, uint256 amount) external {
        lastUser = user;
        require(token.transferFrom(msg.sender, custody, amount), "b3");
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) {
        return 30184;
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

contract LeafB3LockboxTest is PegReady {
    MockEndpoint ep;
    MockB3 b3;
    MockStake farm;
    LeafB3Lockbox box;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address user = address(0xBEEF);
    address custody = address(0xC0DE);

    function setUp() public {
        ep = new MockEndpoint();
        b3 = new MockB3();
        farm = new MockStake(b3, custody);
        vm.prank(owner);
        box = new LeafB3Lockbox(address(b3), address(farm), custody, address(ep), owner, guardian, feeTo, 1_000_000 ether);
        vm.prank(owner);
        box.setPeer(30367, bytes32(uint256(uint160(address(1)))));
        _openSrc(box, owner, 1_000_000 ether);
        b3.mint(user, 10_000 ether);
        vm.deal(user, 1 ether);
    }

    function testCatalogNotABatch() public {
        AssetCatalog.Listing memory a = AssetCatalog.get("hb3");
        assertEq(a.sourceChainIdMain, 8453);
        assertEq(a.innerMainnet, P.B3);
        assertFalse(a.productionEvm);
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hb3");
    }

    function _batch(string calldata id) external pure returns (uint8) {
        return MainnetBatches.batchOf(id);
    }

    function testStakeForLockboxAndB3Leaves() public {
        vm.startPrank(user);
        b3.approve(address(box), 1_000 ether);
        box.sendTo{value: 0.01 ether}(30367, user, 1_000 ether);
        vm.stopPrank();
        assertEq(box.totalLocked(), 1_000 ether);
        assertEq(b3.balanceOf(address(box)), 0);
        assertEq(b3.balanceOf(custody), 1_000 ether);
        assertEq(farm.lastUser(), address(box));
        assertEq(box.claim(), address(0));
        assertFalse(box.winClaimEnabled());
        assertEq(P.WIN, address(0));
        assertEq(P.CLAIM, 0xe69Bc02DC0C4c6dAc306fFDdD2ebd4cf470F0764);
        assertEq(P.CLAIM_DELAYED_WITHDRAWAL, bytes4(0xf41ba29c));
        assertEq(P.STAKE_FOR, bytes4(0x2ee40908));
    }

    function testMinStake() public {
        vm.startPrank(user);
        b3.approve(address(box), 49 ether);
        vm.expectRevert(LeafB3Lockbox.MinStake.selector);
        box.sendTo{value: 0.01 ether}(30367, user, 49 ether);
        vm.stopPrank();
    }

    function testClaimUnsetBlocksPoke() public {
        vm.expectRevert(LeafB3Lockbox.ClaimUnset.selector);
        box.pokeRewards();
    }

    function testCannotSetUnstakeAsClaim() public {
        vm.prank(owner);
        vm.expectRevert(P.UnstakeForbidden.selector);
        box.setClaim(address(1), bytes4(0x2e17de78));
        vm.prank(owner);
        vm.expectRevert(LeafB3Lockbox.ClaimUnset.selector);
        box.setClaim(address(0), P.CLAIM_DELAYED_WITHDRAWAL);
    }

    function testClaimWinPaysB3AsYield() public {
        MockWinClaim win = new MockWinClaim(b3);
        b3.mint(address(win), 10 ether);
        vm.startPrank(owner);
        box.setClaim(address(win), P.CLAIM_DELAYED_WITHDRAWAL);
        box.setWinClaimEnabled(true);
        vm.stopPrank();
        uint256 locked = box.totalLocked();
        box.claimWin(5);
        assertEq(win.lastIndex(), 5);
        assertEq(b3.balanceOf(address(box)), 10 ether);
        assertEq(box.totalLocked(), locked);
    }

    function testInboundBlocked() public {
        bytes memory payload = _msg(box, user, 1 ether);
        ILayerZeroEndpointV2.Origin memory origin =
            ILayerZeroEndpointV2.Origin({srcEid: 30367, sender: bytes32(uint256(uint160(address(1)))), nonce: 1});
        vm.prank(address(ep));
        vm.expectRevert(LeafB3Lockbox.InboundOnly.selector);
        box.lzReceive(origin, bytes32(uint256(1)), payload, address(this), "");
    }

    function testCustodyDrainDegrades() public {
        vm.startPrank(user);
        b3.approve(address(box), 1_000 ether);
        box.sendTo{value: 0.01 ether}(30367, user, 1_000 ether);
        vm.stopPrank();
        vm.prank(custody);
        b3.transfer(user, 1_000 ether);
        box.reportCustody();
        assertEq(uint8(box.health()), uint8(1));
    }
}
