// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {PaperOtcFactory} from "src/premarket/PaperOtcFactory.sol";
import {PremarketAddresses} from "src/premarket/PremarketAddresses.sol";

/// @notice Fork smoke. Skips if the public HyperEVM RPC is down. Never broadcasts.
contract PaperOtcForkTest is Test {
    string constant RPC = "https://rpc.hyperliquid.xyz/evm";

    IERC20 usdm = IERC20(PremarketAddresses.USDM);
    IERC4626 susdm = IERC4626(PremarketAddresses.SUSDM);
    address paper = 0xe40f17915DAa230324030003A197cdAEf2261C0e;

    PaperOtcFactory factory;
    bool forkOk;
    address seller = address(0x5E11);
    address guardian = address(0x6A2D);

    function setUp() public {
        try vm.createSelectFork(RPC) {
            try susdm.convertToAssets(1e12) returns (uint256 assets) {
                forkOk = assets > 0 && susdm.maxWithdraw(address(this)) == 0;
            } catch {
                forkOk = false;
            }
        } catch {
            forkOk = false;
        }
        if (!forkOk) return;
        factory = new PaperOtcFactory(
            address(this), guardian, address(0xFEE), address(usdm), address(susdm), paper
        );
    }

    function testFork_liveWithdrawReverts() public {
        if (!forkOk) return;
        vm.expectRevert();
        susdm.withdraw(1, address(this), address(this));
    }

    function testFork_depositAndCancelReturnsShares() public {
        if (!forkOk) return;
        uint256 amount = 1e6;
        deal(address(usdm), seller, amount);
        vm.startPrank(seller);
        usdm.approve(address(factory), amount);
        uint256 id = factory.createOffer(1e18, 1e6, amount, type(uint256).max);
        uint256 held = susdm.balanceOf(address(factory));
        factory.cancelOffer(id);
        vm.stopPrank();
        assertGt(susdm.balanceOf(seller), 0);
        assertGe(susdm.convertToAssets(susdm.balanceOf(seller)), amount - 2);
        assertEq(usdm.balanceOf(seller), 0);
        assertLt(susdm.balanceOf(address(factory)), held);
    }
}
