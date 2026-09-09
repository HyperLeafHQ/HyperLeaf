// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LeafClaimEscrow} from "src/lz/LeafClaimEscrow.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract PauseTestToken is ERC20 {
    constructor() ERC20("PauseTest", "PT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PauseTestEndpoint is ILayerZeroEndpointV2 {
    uint32 public immutable override eid;

    constructor(uint32 eid_) {
        eid = eid_;
    }

    function send(MessagingParams calldata, address) external payable returns (MessagingReceipt memory r) {
        r.guid = bytes32(uint256(1));
        r.nonce = 1;
        r.fee = MessagingFee(msg.value, 0);
    }

    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee(0, 0);
    }

    function setDelegate(address) external {}
    function setConfig(address, address, SetConfigParam[] calldata) external {}
    function getConfig(address, address, uint32, uint32) external pure returns (bytes memory) {
        return "";
    }
    function skip(address, uint32, bytes32, uint64) external {}
}

contract LeafClaimEscrowPauseTest is Test {
    PauseTestEndpoint endpoint;
    PauseTestToken leaf;
    PauseTestToken want;
    LeafClaimEscrow escrow;

    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address seller = address(0xA1);
    address buyer = address(0xB2);
    address sourceRecipient = address(0xC3);
    address remotePeer = address(0xD4);

    uint32 constant LOCAL_EID = 30367;
    uint32 constant REMOTE_EID = 30102;

    function setUp() public {
        endpoint = new PauseTestEndpoint(LOCAL_EID);
        leaf = new PauseTestToken();
        want = new PauseTestToken();

        vm.prank(owner);
        escrow = new LeafClaimEscrow(address(endpoint), owner, guardian, address(0xFEE));

        vm.startPrank(owner);
        escrow.setPeer(REMOTE_EID, remotePeer);
        escrow.setMarket(address(leaf), address(want), bytes32(0), true);
        vm.stopPrank();

        leaf.mint(seller, 100 ether);
    }

    function testRemoteFillRevertsWhilePausedAndLeavesEscrowUntouched() public {
        vm.startPrank(seller);
        leaf.approve(address(escrow), 100 ether);
        uint256 id = escrow.list(
            address(leaf),
            100 ether,
            address(want),
            70 ether,
            sourceRecipient,
            uint64(block.timestamp + 7 days)
        );
        vm.stopPrank();

        uint256 escrowLeafBefore = leaf.balanceOf(address(escrow));
        uint256 buyerLeafBefore = leaf.balanceOf(buyer);

        vm.prank(guardian);
        escrow.pause();

        bytes memory fillMsg = abi.encode(
            uint8(escrow.OP_FILL()),
            id,
            buyer,
            uint256(70 ether),
            sourceRecipient,
            address(want)
        );
        ILayerZeroEndpointV2.Origin memory origin = ILayerZeroEndpointV2.Origin({
            srcEid: REMOTE_EID,
            sender: bytes32(uint256(uint160(remotePeer))),
            nonce: 1
        });

        vm.prank(address(endpoint));
        vm.expectRevert();
        escrow.lzReceive(origin, bytes32(uint256(1)), fillMsg, address(0), "");

        (, , , , , , , LeafClaimEscrow.Status status) = escrow.orders(id);
        assertEq(uint8(status), uint8(LeafClaimEscrow.Status.Open));
        assertEq(leaf.balanceOf(address(escrow)), escrowLeafBefore);
        assertEq(leaf.balanceOf(buyer), buyerLeafBefore);
    }
}
