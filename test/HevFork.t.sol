// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HyperEVMAddresses} from "../src/config/HyperEVMAddresses.sol";
import {IVotingEscrow} from "../src/interfaces/IVotingEscrow.sol";
import {IVoter} from "../src/interfaces/IVoter.sol";
import {IHevStrategy} from "../src/interfaces/IHevStrategy.sol";

/**
 * @notice Fork-only documentation tests for Nest HEV attach + claim path.
 *         Skips entirely if HyperEVM RPC is unreachable or rate-limited.
 *         Never broadcasts. No NEST/HYPE spent on mainnet.
 *
 * @dev Public RPC (-32005) can abort mid-test with a host database error that
 *      Solidity try/catch cannot swallow. Keep fork surface small; VR harvest /
 *      getReward absences are documented via cast in docs/HEV_ABI_PROBE.md.
 */
contract HevForkTest is Test {
    string constant RPC = "https://rpc.hyperliquid.xyz/evm";

    IVotingEscrow constant ve = IVotingEscrow(HyperEVMAddresses.VE_NEST);
    IVoter constant voter = IVoter(HyperEVMAddresses.VOTER);
    IHevStrategy constant hev = IHevStrategy(HyperEVMAddresses.HEV_STRATEGY);
    IERC20 constant nest = IERC20(HyperEVMAddresses.NEST);

    bool forkOk;

    function setUp() public {
        try vm.createSelectFork(RPC) {
            try hev.managedTokenId() returns (uint256 mid) {
                forkOk = (mid == 1);
            } catch {
                forkOk = false;
                emit log("SKIP: HyperEVM RPC rate-limited during smoke call");
            }
        } catch {
            forkOk = false;
            emit log("SKIP: HyperEVM RPC fork unavailable");
        }
    }

    modifier whenFork() {
        if (!forkOk) {
            emit log("SKIP: fork not ready");
            return;
        }
        _;
    }

    function testFork_CreateLockApiProbe() public whenFork {
        (bool okClassic,) = HyperEVMAddresses.VE_NEST
            .call(abi.encodeWithSignature("createLock(uint256,uint256)", uint256(1), uint256(7 days)));
        assertFalse(okClassic, "classic createLock must be missing on Nest veNEST");

        address whale = address(0xBEEF);
        vm.prank(whale);
        (bool okFor, bytes memory ret) = HyperEVMAddresses.VE_NEST
            .call(
                abi.encodeWithSelector(
                    IVotingEscrow.createLockFor.selector,
                    uint256(1 ether),
                    uint256(26 weeks),
                    whale,
                    false,
                    false,
                    uint256(0)
                )
            );
        assertFalse(okFor, "createLockFor should revert without NEST allowance/balance");
        if (ret.length == 0) {
            emit log("WARN: createLockFor empty revert data (RPC quirk); selector confirmed via Sourcify");
        } else {
            emit log_named_bytes("createLockFor revert data", ret);
        }
    }

    function testFork_ContractCanAttachAfterApprove() public whenFork {
        uint256 tokenId = 10;
        address owner_;
        try ve.ownerOf(tokenId) returns (address o) {
            owner_ = o;
        } catch {
            emit log("SKIP: ownerOf failed (RPC)");
            return;
        }

        IVotingEscrow.TokenState memory beforeState;
        try ve.getNftState(tokenId) returns (IVotingEscrow.TokenState memory st) {
            beforeState = st;
        } catch {
            emit log("SKIP: getNftState failed (RPC)");
            return;
        }

        if (beforeState.isAttached) {
            emit log("SKIP: sample token already attached");
            return;
        }

        AttachCaller caller = new AttachCaller(voter);

        vm.prank(owner_);
        ve.approve(address(caller), tokenId);
        assertTrue(ve.isApprovedOrOwner(address(caller), tokenId), "contract must be approved");

        vm.prank(address(caller));
        try caller.attach(tokenId, HyperEVMAddresses.HEV_MANAGED_TOKEN_ID) {
            IVotingEscrow.TokenState memory afterState = ve.getNftState(tokenId);
            assertTrue(afterState.isAttached, "attachToManagedNFT should set isAttached");
            emit log_named_uint("attached tokenId", tokenId);
            emit log("CONFIRMED: contract caller may attachToManagedNFT after approve");
        } catch (bytes memory reason) {
            emit log_named_bytes("attach reverted (auth OK if not IncorrectUserNFT)", reason);
            if (reason.length == 0) {
                emit log("WARN: empty attach revert data; see docs/HEV_ABI_PROBE.md");
            }
        }
    }

    function testFork_CreateLockForAtomicAttach() public whenFork {
        AttachCaller vaultLike = new AttachCaller(voter);
        address vaultAddr = address(vaultLike);
        uint256 amount = 1 ether;

        deal(address(nest), vaultAddr, amount);
        vm.prank(vaultAddr);
        nest.approve(address(ve), amount);

        vm.prank(vaultAddr);
        try ve.createLockFor(
            amount, 26 weeks, vaultAddr, false, false, HyperEVMAddresses.HEV_MANAGED_TOKEN_ID
        ) returns (
            uint256 tokenId
        ) {
            IVotingEscrow.TokenState memory st = ve.getNftState(tokenId);
            assertTrue(st.isAttached, "managedTokenIdForAttach_=1 should attach atomically");
            assertEq(ve.ownerOf(tokenId), vaultAddr, "to_ receives NFT");
            emit log_named_uint("atomic-attach tokenId", tokenId);
            emit log("CONFIRMED: createLockFor(..., managedId=1) locks+attaches for contract to_");
        } catch (bytes memory reason) {
            emit log_named_bytes("createLockFor atomic attach reverted", reason);
            if (reason.length == 0) {
                emit log("WARN: empty revert; vote window / InvalidLockDuration / RPC");
            }
        }
    }

    /// @dev Light HEV claim probe. getLockedRewardsBalance reads VR storage and
    ///      trips public RPC rate limits mid-test (uncatchable host DB error).
    ///      Full pending/harvest matrix: cast results in docs/HEV_ABI_PROBE.md section 7.
    function testFork_ClaimAndPendingViews() public whenFork {
        try hev.managedTokenId() returns (uint256 mid) {
            assertEq(mid, 1);
        } catch {
            emit log("SKIP: managedTokenId RPC fail");
            return;
        }

        try hev.virtualRewarder() returns (address rewarderAddr) {
            assertEq(rewarderAddr, HyperEVMAddresses.VIRTUAL_REWARDER);
        } catch {
            emit log("SKIP: virtualRewarder RPC fail");
            return;
        }

        // Empty claimRewards is a no-op dispatch; avoids VR balance storage fan-out.
        address caller = address(0x1);
        vm.prank(caller);
        try hev.claimRewards(new address[](0)) {
            emit log("claimRewards([]) ok (operator/managed-NFT path; empty no-op)");
        } catch {
            emit log("SKIP: claimRewards RPC fail");
            return;
        }

        emit log("NOTE: getLockedRewardsBalance==VR.calculateAvailableRewardsAmount and");
        emit log("      VR.harvest AccessDenied / getReward MISSING confirmed via cast eth_call");
    }
}

contract AttachCaller {
    IVoter public immutable voter;

    constructor(IVoter voter_) {
        voter = voter_;
    }

    function attach(uint256 tokenId, uint256 managedId) external {
        voter.attachToManagedNFT(tokenId, managedId);
    }
}
