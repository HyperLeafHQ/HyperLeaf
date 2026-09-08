// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {TestnetCatalog} from "src/lz/TestnetCatalog.sol";

/// @notice Set listingTag + per-tx/day caps. OFT also gets supplyCap.
///         Set OPEN_BRIDGE=true only after peers and DVN are verified on-chain.
contract OpenPeg is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        string memory id = vm.envOr("ASSET", string("hxsquid"));
        AssetCatalog.Listing memory a = _listing(id);
        bytes32 tag = keccak256(bytes(a.id));
        uint256 cap = vm.envOr("PEG_CAP", a.defaultCap);
        uint256 ceiling = vm.envOr("INNER_SUPPLY_CEILING", uint256(0));
        bool open = vm.envOr("OPEN_BRIDGE", false);

        vm.startBroadcast();
        LeafOApp app = LeafOApp(oapp);
        app.setListingTag(tag);
        app.setLimits(cap, cap);
        if (ceiling != 0) app.setInnerSupplyCeiling(ceiling);
        try LeafOFT(oapp).setSupplyCap(cap) {} catch {}
        if (open) app.openBridge();
        vm.stopBroadcast();

        console2.log("peg tag", vm.toString(tag));
        console2.log("cap", cap);
        console2.log("opened", open);
    }

    function _listing(string memory id) internal view returns (AssetCatalog.Listing memory) {
        uint256 c = block.chainid;
        if (c == 84532 || c == 998 || c == 97 || c == 80069) return TestnetCatalog.get(id);
        return AssetCatalog.get(id);
    }
}
