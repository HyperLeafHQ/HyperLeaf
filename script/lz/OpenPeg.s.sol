import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LeafOApp} from "src/lz/LeafOApp.sol";
import {LeafOFT} from "src/lz/LeafOFT.sol";
import {AssetCatalog} from "src/lz/AssetCatalog.sol";
import {LeafLbtcPolicy} from "src/lz/LeafLbtcPolicy.sol";

/// @notice Set listingTag + per-tx/day caps. OFT also gets supplyCap.
///         Set OPEN_BRIDGE=true only after peers and DVN are verified on-chain.
///         PEG_CAP is dest share units. For hlbtc, default = inner defaultCap * 1e10.
contract OpenPeg is Script {
    function run() external {
        address oapp = vm.envAddress("OAPP");
        string memory id = vm.envString("ASSET");
        AssetCatalog.Listing memory a = AssetCatalog.get(id);
        bytes32 tag = keccak256(bytes(a.id));
        uint256 cap = vm.envOr("PEG_CAP", a.defaultCap * LeafLbtcPolicy.shareScaleOf(id));
        uint256 ceiling = vm.envOr("INNER_SUPPLY_CEILING", uint256(0));
        bool open = vm.envOr("OPEN_BRIDGE", false);

        if (block.chainid == a.sourceChainIdMain && keccak256(bytes(a.id)) == keccak256("hlbtc")) {
            require(ceiling != 0, "hlbtc INNER_SUPPLY_CEILING");
            require(ceiling > IERC20(a.innerMainnet).totalSupply(), "ceiling <= live LBTC supply");
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
        console2.log("cap (share units)", cap);
        console2.log("opened", open);
    }
}