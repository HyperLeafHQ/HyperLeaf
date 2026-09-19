// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PegReady} from "test/lz/PegReady.sol";
import {LeafOmnichainHolder} from "src/lz/LeafOmnichainHolder.sol";
import {LeafVirtualsLockbox} from "src/lz/LeafVirtualsLockbox.sol";
import {LeafInboundLockbox} from "src/lz/LeafInboundLockbox.sol";
import {LeafOFTAdapter} from "src/lz/LeafOFTAdapter.sol";
import {LeafYieldFee} from "src/lz/LeafYieldFee.sol";
import {LeafCreate2} from "src/lz/LeafCreate2.sol";
import {LeafMerkleClaim} from "src/lz/LeafMerkleClaim.sol";
import {LeafKaitoPolicy} from "src/lz/LeafKaitoPolicy.sol";
import {LeafVirtualsPolicy} from "src/lz/LeafVirtualsPolicy.sol";
import {LeafForbiddenSelectors} from "src/lz/LeafForbiddenSelectors.sol";
import {MainnetBatches} from "src/lz/MainnetBatches.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LayerZeroAddresses as A} from "src/lz/LayerZeroAddresses.sol";
import {IVirtualsStake} from "src/lz/IVirtualsStake.sol";
import {ILayerZeroEndpointV2, SetConfigParam} from "src/lz/interfaces/ILayerZeroEndpointV2.sol";

contract Drop is ERC20 {
    constructor() ERC20("NOVER", "NOVER") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract Inner is ERC20 {
    constructor() ERC20("sKAITO", "sKAITO") {}
    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockMerkle {
    IERC20 public immutable token;
    address public lastAccount;
    uint256 public lastIndex;
    uint256 public lastAmount;

    constructor(IERC20 token_) {
        token = token_;
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata) external {
        lastIndex = index;
        lastAccount = account;
        lastAmount = amount;
        token.transfer(account, amount);
    }
}

contract MockStake is IVirtualsStake {
    IERC20 public immutable token;
    constructor(IERC20 token_) {
        token = token_;
    }
    function stake(uint256 amount, uint8, bool) external {
        token.transferFrom(msg.sender, address(this), amount);
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

contract LeafMerkleTest is PegReady {
    address owner = address(0xA11CE);
    address guardian = address(0xB0B);
    address feeTo = address(0xFEE);
    address converter = address(0xC0);
    Drop drop;
    Inner inner;
    MockMerkle dist;
    MockEndpoint ep;

    function setUp() public {
        drop = new Drop();
        inner = new Inner();
        dist = new MockMerkle(drop);
        ep = new MockEndpoint();
    }

    function testSelectorIsVirtualsMerkleNotRewardsPoke() public pure {
        assertEq(LeafMerkleClaim.SELECTOR, bytes4(0x2e7ba6ef));
        assertEq(LeafKaitoPolicy.MERKLE_CLAIM, bytes4(0x2e7ba6ef));
        assertEq(LeafVirtualsPolicy.MERKLE_CLAIM, bytes4(0x2e7ba6ef));
        assertTrue(LeafForbiddenSelectors.forbidden(LeafMerkleClaim.SELECTOR));
    }

    function testHolderPokeForcesAccountThis() public {
        vm.prank(owner);
        LeafOmnichainHolder h = new LeafOmnichainHolder(owner);
        drop.mint(address(dist), 44e18);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(uint256(1));
        vm.startPrank(owner);
        h.setPrincipal(address(inner), true);
        h.setConverter(converter);
        h.setMerkleDistributor(address(dist), true);
        vm.stopPrank();
        h.pokeMerkleClaim(address(dist), 2086, 44e18, proof);
        assertEq(dist.lastAccount(), address(h));
        assertEq(dist.lastIndex(), 2086);
        assertEq(drop.balanceOf(address(h)), 44e18);
        vm.prank(owner);
        h.sweep(drop, converter);
        assertEq(drop.balanceOf(converter), 44e18);
    }

    function testHolderCannotMerklePrincipal() public {
        vm.prank(owner);
        LeafOmnichainHolder h = new LeafOmnichainHolder(owner);
        vm.startPrank(owner);
        h.setPrincipal(address(inner), true);
        vm.expectRevert(LeafOmnichainHolder.BadMerkleDistributor.selector);
        h.setMerkleDistributor(address(inner), true);
        vm.stopPrank();
    }

    function testHolderRewardsSelectorStillDeniesMerkleAbi() public {
        vm.prank(owner);
        LeafOmnichainHolder h = new LeafOmnichainHolder(owner);
        vm.prank(owner);
        vm.expectRevert(LeafOmnichainHolder.ForbiddenRewardsSelector.selector);
        h.setRewardsSelector(LeafMerkleClaim.SELECTOR);
    }

    function testVirtualsLockboxMerkleAndRejectsStake() public {
        MockStake stake = new MockStake(inner);
        vm.startPrank(owner);
        LeafVirtualsLockbox box = new LeafVirtualsLockbox(
            address(inner), address(stake), address(ep), owner, guardian, feeTo, 0
        );
        vm.expectRevert(LeafInboundLockbox.BadStake.selector);
        box.setMerkleDistributor(address(stake), true);
        box.setMerkleDistributor(address(dist), true);
        box.setConverter(converter);
        box.setConvertYieldToHype(true);
        vm.stopPrank();
        drop.mint(address(dist), 1e18);
        bytes32[] memory proof = new bytes32[](0);
        box.pokeMerkleClaim(address(dist), 1, 1e18, proof);
        assertEq(dist.lastAccount(), address(box));
        assertEq(drop.balanceOf(address(box)), 1e18);
        box.pullYield(drop, converter);
        assertEq(drop.balanceOf(converter), 1e18);
    }

    function testAdapterMerkleDoesNotPullInner() public {
        vm.startPrank(owner);
        LeafOFTAdapter box = new LeafOFTAdapter(address(inner), address(ep), owner, guardian, feeTo, 0);
        box.setMerkleDistributor(address(dist), true);
        box.setConverter(converter);
        box.setConvertYieldToHype(true);
        vm.expectRevert(LeafYieldFee.ForbiddenRewardsSelector.selector);
        box.setRewardsSelector(LeafMerkleClaim.SELECTOR);
        vm.stopPrank();
        inner.mint(address(box), 5e18);
        drop.mint(address(dist), 2e18);
        bytes32[] memory proof = new bytes32[](0);
        box.pokeMerkleClaim(address(dist), 7, 2e18, proof);
        assertEq(dist.lastAccount(), address(box));
        assertEq(inner.balanceOf(address(box)), 5e18);
        box.pullYield(drop, converter);
        vm.expectRevert(LeafOFTAdapter.CannotPullInner.selector);
        box.pullYield(inner, converter);
    }

    function testCreate2AdapterMatchesOnCanonicalEndpoint() public view {
        bytes memory init = abi.encodePacked(
            type(LeafOFTAdapter).creationCode,
            abi.encode(LeafKaitoPolicy.SKAITO, A.ENDPOINT_ETH, owner, guardian, feeTo, uint256(0))
        );
        address p = LeafCreate2.predict(LeafCreate2.ADAPTER_SALT, init);
        bytes memory initBase = abi.encodePacked(
            type(LeafOFTAdapter).creationCode,
            abi.encode(LeafKaitoPolicy.SKAITO, A.endpoint(8453), owner, guardian, feeTo, uint256(0))
        );
        assertEq(p, LeafCreate2.predict(LeafCreate2.ADAPTER_SALT, initBase));
        assertEq(A.endpoint(1), A.endpoint(8453));
        assertEq(A.endpoint(42161), A.endpoint(8453));
        assertTrue(A.endpoint(4663) != A.endpoint(8453));
    }

    function testCreate2VirtualsMatchesOnCanonicalEndpoint() public view {
        bytes memory init = abi.encodePacked(
            type(LeafVirtualsLockbox).creationCode,
            abi.encode(
                LeafVirtualsPolicy.VIRTUAL,
                LeafVirtualsPolicy.STAKE,
                A.ENDPOINT_ETH,
                owner,
                guardian,
                feeTo,
                uint256(0)
            )
        );
        address p = LeafCreate2.predict(LeafCreate2.VIRTUALS_SALT, init);
        bytes memory initArb = abi.encodePacked(
            type(LeafVirtualsLockbox).creationCode,
            abi.encode(
                LeafVirtualsPolicy.VIRTUAL,
                LeafVirtualsPolicy.STAKE,
                A.endpoint(42161),
                owner,
                guardian,
                feeTo,
                uint256(0)
            )
        );
        assertEq(p, LeafCreate2.predict(LeafCreate2.VIRTUALS_SALT, initArb));
        bytes memory initRh = abi.encodePacked(
            type(LeafVirtualsLockbox).creationCode,
            abi.encode(
                LeafVirtualsPolicy.VIRTUAL,
                LeafVirtualsPolicy.STAKE,
                A.endpoint(4663),
                owner,
                guardian,
                feeTo,
                uint256(0)
            )
        );
        assertTrue(p != LeafCreate2.predict(LeafCreate2.VIRTUALS_SALT, initRh));
    }

    function testPinsNotABatch() public {
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hkaito");
        vm.expectRevert(MainnetBatches.NotThisBatch.selector);
        this._batch("hvirtualmax");
        LeafKaitoPolicy.requireSkaito(LeafKaitoPolicy.SKAITO);
        vm.expectRevert(LeafKaitoPolicy.NotSkaito.selector);
        this._requireKaito(LeafKaitoPolicy.KAITO);
        LeafVirtualsPolicy.requireVirtual(LeafVirtualsPolicy.VIRTUAL);
        assertEq(AssetCatalog.get("hkaito").innerMainnet, LeafKaitoPolicy.SKAITO);
        assertEq(AssetCatalog.get("hvirtualmax").innerMainnet, LeafVirtualsPolicy.VIRTUAL);
        assertEq(LeafVirtualsPolicy.MAX_WEEKS, 104);
    }

    function _batch(string calldata id) external pure {
        MainnetBatches.requireBatch(id, 4);
    }

    function _requireKaito(address inner_) external pure {
        LeafKaitoPolicy.requireSkaito(inner_);
    }
}
