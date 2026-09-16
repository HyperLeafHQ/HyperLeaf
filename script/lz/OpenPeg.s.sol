// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LeafLbtcPolicy} from "src/lz/LeafLbtcPolicy.sol";

/// @notice Set listingTag + per-tx/day caps. OFT also gets supplyCap.
///         cap 0 = no HyperLeaf intake limit (hxSQUID / hAVNT). Inner ceiling
///         still required on source. Set OPEN_BRIDGE=true only after peers+DVN.
contract OpenPeg is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        string memory id = vm.envString("ASSET");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        bytes32 tag = keccak256(bytes(a.id));
        uint256 cap;
        try vm.envUint("PEG_CAP") returns (uint256 explicitCap) {
            cap = explicitCap;
        } catch {
            cap = a.defaultCap * LeafLbtcPolicy.shareScaleOf(id);
        }
        uint8 decimals = a.innerMainnet == address(0) ? 18 : IERC20Metadata(a.innerMainnet).decimals();
        uint256 ceiling = vm.envOr("INNER_SUPPLY_CEILING", uint256(0));
        bool open = vm.envOr("OPEN_BRIDGE", false);
        // cap 0 = no HyperLeaf intake limit. Inner ceiling still required on source.

        // Source lockbox: ceiling is an anti-print tripwire on the *inner token's
        // global supply*, not HyperLeaf's deposit cap. Mixing the two is
        // InnerSupplyBreach (hxSQUID v1). Dest OFT has no canonical inner.
        if (block.chainid == a.sourceChainIdMain && a.innerMainnet != address(0)) {
            uint256 live = IERC20(a.innerMainnet).totalSupply();
            require(ceiling != 0, "INNER_SUPPLY_CEILING required on source");
            require(ceiling > live, "ceiling <= live inner totalSupply");
            console2.log("live inner totalSupply", live);
            console2.log("INNER_SUPPLY_CEILING", ceiling);
        }

        vm.startBroadcast();
        LeafOApp app = LeafOApp(oapp);
        app.setListingTag(tag);
        app.setLimits(cap, cap);
        if (ceiling != 0) app.setInnerSupplyCeiling(ceiling);
        try LeafOFT(oapp).setSupplyCap(cap) {} catch {}
        if (open) app.openBridge();
        vm.stopBroadcast();

        console2.log("peg tag", vm.toString(tag));
        console2.log("ASSET", a.id);
        console2.log("decimals", decimals);
        console2.log("cap (share units)", cap);
        console2.log("opened", open);
    }
}
