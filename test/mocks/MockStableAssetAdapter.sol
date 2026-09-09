// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IStableAssetAdapter} from "src/interfaces/IStableAssetAdapter.sol";

contract MockStableAssetAdapter is IStableAssetAdapter {
    mapping(bytes32 => PegState) internal pegs;
    mapping(bytes32 => ExitState) internal exits;

    function setPeg(bytes32 id, PegState calldata p) external { pegs[id] = p; }
    function setExit(bytes32 id, ExitState calldata e) external { exits[id] = e; }

    function pegState(bytes32 id) external view returns (PegState memory) { return pegs[id]; }
    function exitState(bytes32 id) external view returns (ExitState memory) { return exits[id]; }

    function previewPrimaryExit(bytes32 id, uint256 shares)
        external
        view
        returns (uint256 assets, uint256 slippageBps)
    {
        PegState memory p = pegs[id];
        if (p.referencePrice == 0) return (0, type(uint256).max);
        assets = (shares * p.primaryRedeemPrice) / 1e18;
        slippageBps = p.deviationBps;
    }

    function primaryExit(bytes32 id, uint256 shares, uint256 minAssets, address)
        external
        view
        returns (uint256 assets)
    {
        (assets,) = this.previewPrimaryExit(id, shares);
        require(assets >= minAssets, "slippage");
    }
}
