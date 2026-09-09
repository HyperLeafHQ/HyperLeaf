// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {LeafHypeRewarder} from "src/lz/LeafHypeRewarder.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";
import {PegReady} from "test/lz/PegReady.sol";

contract RewardTransferToken is ERC20 {
    constructor() ERC20("WHYPE", "WHYPE") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract RewardTransferEndpoint is ILayerZeroEndpointV2 {
    function eid() external pure returns (uint32) { return 30184; }
    function send(MessagingParams calldata, address) external payable returns (MessagingReceipt memory r) { r.guid = bytes32(uint256(1)); }
    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) { return MessagingFee(0, 0); }
    function setDelegate(address) external {}
    function setConfig(address, address, SetConfigParam[] calldata) external {}
    function getConfig(address, address, uint32, uint32) external pure returns (bytes memory) { return ""; }
    function skip(address, uint32, bytes32, uint64) external {}
}

contract LeafRewardTransferTest is PegReady {
    RewardTransferToken hype;
    RewardTransferEndpoint endpoint;
    LeafOFT leaf;
    LeafHypeRewarder rewarder;

    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address alice = address(0xA1);
    address bob = address(0xB2);
    bytes32 constant ID = keccak256("transfer-test");
    uint256 constant CAP = 1_000e18;

    function setUp() public {
        hype = new RewardTransferToken();
        endpoint = new RewardTransferEndpoint();
        vm.startPrank(owner);
        leaf = new LeafOFT("Leaf", "hLEAF", address(endpoint), owner, guardian);
        rewarder = new LeafHypeRewarder(address(hype), owner, feeTo);
        leaf.setHypeRewarder(address(rewarder), ID);
        rewarder.register(ID, address(leaf));
        leaf.setPeer(1, bytes32(uint256(1)));
        leaf.setSupplyCap(CAP);
        vm.stopPrank();
        _openSrc(leaf, owner, CAP);
        vm.deal(owner, 1 ether);
    }

    function _mint(address to, uint256 amount) internal {
        bytes memory payload = _msg(leaf, to, amount);
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: 1, sender: bytes32(uint256(1)), nonce: 1
        });
        vm.prank(address(endpoint));
        leaf.lzReceive(origin, bytes32(uint256(1)), payload, address(0), "");
    }

    function _notify(uint256 amount) internal {
        hype.mint(address(this), amount);
        hype.approve(address(rewarder), amount);
        rewarder.notify(ID, amount);
    }

    function testTransferPreservesSellerAccruedRewardAndBuyerStartsAtZero() public {
        _mint(alice, 100e18);
        _notify(100e18);
        assertEq(rewarder.pending(ID, alice), 99e18);

        vm.prank(alice);
        leaf.transfer(bob, 40e18);

        assertEq(rewarder.pending(ID, alice), 99e18);
        assertEq(rewarder.pending(ID, bob), 0);

        _notify(100e18);
        assertEq(rewarder.pending(ID, alice), 158.4e18);
        assertEq(rewarder.pending(ID, bob), 39.6e18);
    }
}
