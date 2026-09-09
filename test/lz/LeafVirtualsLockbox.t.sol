// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LeafVirtualsLockbox} from "src/lz/LeafVirtualsLockbox.sol";
import {LeafClosedOFT} from "src/lz/LeafClosedOFT.sol";
import {IVirtualsStake} from "src/lz/IVirtualsStake.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract MockToken is ERC20 {
    constructor() ERC20("VIRTUAL", "VIRTUAL") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockVirtualsStake is IVirtualsStake {
    IERC20 public immutable token;
    uint256 public lastAmount;
    uint8 public lastWeeks;
    bool public lastAuto;
    address public lastCaller;

    constructor(IERC20 token_) {
        token = token_;
    }

    function stake(uint256 amount, uint8 numWeeks, bool autoRenew) external {
        lastAmount = amount;
        lastWeeks = numWeeks;
        lastAuto = autoRenew;
        lastCaller = msg.sender;
        token.transferFrom(msg.sender, address(this), amount);
    }
}

contract MockEndpoint is ILayerZeroEndpointV2 {
    uint32 public eid = 30184;
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

contract LeafVirtualsLockboxTest is PegReady {
    MockEndpoint ep;
    MockToken virtual_;
    MockVirtualsStake stake;
    LeafVirtualsLockbox box;
    LeafClosedOFT oft;
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address alice = address(0xA1);

    function setUp() public {
        ep = new MockEndpoint();
        virtual_ = new MockToken();
        stake = new MockVirtualsStake(virtual_);
        vm.startPrank(owner);
        box = new LeafVirtualsLockbox(
            address(virtual_), address(stake), address(ep), owner, guardian, feeTo, 10_000e18
        );
        oft = new LeafClosedOFT("Hyperleaf VIRTUAL MAX", "hVIRTUALMAX", uint32(104 weeks), address(ep), owner, guardian);
        box.setPeer(30367, address(uint160(uint256(uint160(address(oft))))));
        vm.stopPrank();
        _openPair(box, oft, owner, 10_000e18);
        virtual_.mint(alice, 100e18);
        vm.deal(alice, 1 ether);
    }

    function testStakeIsAutoMaxLock() public {
        vm.startPrank(alice);
        virtual_.approve(address(box), 1e18);
        box.sendTo{value: 0.01 ether}(30367, alice, 1e18);
        vm.stopPrank();
        assertEq(stake.lastAmount(), 1e18);
        assertEq(stake.lastWeeks(), 104);
        assertTrue(stake.lastAuto());
        assertEq(stake.lastCaller(), address(box));
        assertEq(virtual_.balanceOf(address(box)), 0);
        assertEq(virtual_.balanceOf(address(stake)), 1e18);
        assertEq(box.totalLocked(), 1e18);
    }

    function testClosedOftCannotSend() public {
        vm.expectRevert(LeafClosedOFT.ExitViaMarketOnly.selector);
        oft.send(1, bytes32(uint256(1)), 1, alice);
    }

    function testMaxWeeksConstant() public view {
        assertEq(box.MAX_WEEKS(), 104);
    }
}
