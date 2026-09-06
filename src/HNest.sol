// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {INestVaultHype} from "./interfaces/INestVaultHype.sol";

/**
 * @title HNest
 * @notice Liquid staking receipt for NestVault deposits.
 *         Peer-to-peer transfers settle residual HYPE ERC20 via vault hooks so
 *         accrued residual tokens follow the correct holder (MasterChef debt pattern).
 *         Not Nest liquid HYPE / MEGAHYPE rewards.
 */
contract HNest is ERC20, ERC20Permit {
    address public immutable vault;

    error OnlyVault();

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    constructor(address _vault) ERC20("Hyperliquid NEST", "hNEST") ERC20Permit("Hyperliquid NEST") {
        vault = _vault;
    }

    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyVault {
        _burn(from, amount);
    }

    /**
     * @dev On P2P transfers: settle pending residual HYPE for both parties before balances
     *      change, then update debts after. Mint/burn skip hooks (vault manages debt).
     */
    function _update(address from, address to, uint256 value) internal override {
        bool isTransfer = from != address(0) && to != address(0);
        if (isTransfer) {
            INestVaultHype(vault).settleResidualHype(from);
            INestVaultHype(vault).settleResidualHype(to);
        }
        super._update(from, to, value);
        if (isTransfer) {
            INestVaultHype(vault).updateDebt(from);
            INestVaultHype(vault).updateDebt(to);
        }
    }
}
