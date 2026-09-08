// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ILeafOmnichainHolder {
    function release(IERC20 token, address to, uint256 amount) external;
    function pokeRewards() external payable;
}

/// @title LeafOmnichainHolder
/// @notice Identical CREATE2 initcode on every EVM → same address. Home chain
///         holds inner (adapter may `release`). Other chains: `pokeClaim` + `sweep`.
///         Factory: 0x4e59b44847b379578588920cA78FbF26c0B4956C (Arachnid).
contract LeafOmnichainHolder is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => bool) public isAdapter;
    mapping(address => bool) public isPrincipal;
    mapping(address => bool) public claimTarget;
    mapping(address => bytes4) public claimSelector;
    address public converter;
    address public principal;
    bytes4 public rewardsSelector;

    error ZeroAddress();
    error NotAdapter();
    error BadClaimTarget();
    error BadClaimSelector();
    error ClaimFailed();
    error Principal();
    error ForbiddenRewardsSelector();
    error BadConverter();

    event AdapterSet(address indexed adapter, bool allowed);
    event PrincipalSet(address indexed token, bool ok);
    event ClaimTargetSet(address indexed target, bool allowed);
    event ClaimCallSet(address indexed target, bytes4 selector);
    event ConverterSet(address indexed converter);
    event RewardsSelectorSet(bytes4 selector);
    event Released(address indexed token, address indexed to, uint256 amount);
    event Swept(address indexed token, address indexed to, uint256 amount);

    constructor(address owner_) Ownable(owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
    }

    receive() external payable {}

    function setAdapter(address a, bool ok) external onlyOwner {
        if (a == address(0)) revert ZeroAddress();
        isAdapter[a] = ok;
        emit AdapterSet(a, ok);
    }

    function setPrincipal(address t, bool ok) external onlyOwner {
        if (t == address(0)) revert ZeroAddress();
        isPrincipal[t] = ok;
        if (ok) principal = t;
        emit PrincipalSet(t, ok);
    }

    function setClaimTarget(address t, bool ok) external onlyOwner {
        if (t == address(0) || isPrincipal[t]) revert BadClaimTarget();
        claimTarget[t] = ok;
        if (!ok) claimSelector[t] = bytes4(0);
        emit ClaimTargetSet(t, ok);
    }

    function setClaimCall(address t, bytes4 selector) external onlyOwner {
        if (t == address(0) || isPrincipal[t] || selector == bytes4(0)) revert BadClaimTarget();
        claimTarget[t] = true;
        claimSelector[t] = selector;
        emit ClaimCallSet(t, selector);
    }

    function setConverter(address c) external onlyOwner {
        if (c == address(0)) revert ZeroAddress();
        converter = c;
        emit ConverterSet(c);
    }

    function setRewardsSelector(bytes4 s) external onlyOwner {
        // Keep in sync with LeafYieldFee._forbiddenRewardsSelector.
        if (s != bytes4(0) && (s == bytes4(0x1e9a6950) || s == bytes4(0xb460af94) || s == bytes4(0xba087652)
            || s == bytes4(0x9343d9e1) || s == bytes4(0xcdac52ed) || s == bytes4(0x1e83409a)
            || s == bytes4(0x9ad82aa0) || s == bytes4(0x50b3f984)
            || s == bytes4(0xc9d2ff9d) || s == bytes4(0x2e1a7d4d)
            || s == bytes4(0x1338736f) || s == bytes4(0x6e553f65) || s == bytes4(0x94bf804d)
            || s == bytes4(0x397a1b28) || s == bytes4(0x0efe6a8b) || s == bytes4(0x1d7d4ebc)
            || s == bytes4(0x2e7ba6ef))) revert ForbiddenRewardsSelector();
        rewardsSelector = s;
        emit RewardsSelectorSet(s);
    }

    function release(IERC20 token, address to, uint256 amount) external nonReentrant {
        if (!isAdapter[msg.sender]) revert NotAdapter();
        token.safeTransfer(to, amount);
        emit Released(address(token), to, amount);
    }

    function pokeClaim(address t, bytes calldata data) external payable nonReentrant {
        if (!claimTarget[t] || isPrincipal[t]) revert BadClaimTarget();
        if (data.length < 4) revert BadClaimSelector();
        if (claimSelector[t] == bytes4(0) || bytes4(data[0:4]) != claimSelector[t]) revert BadClaimSelector();
        (bool ok,) = t.call{value: msg.value}(data);
        if (!ok) revert ClaimFailed();
    }

    /// @notice Squid claimRewards(this, max). Selector is not redeem.
    function pokeRewards() external payable nonReentrant {
        address p = principal;
        bytes4 s = rewardsSelector;
        if (p == address(0) || s == bytes4(0)) revert BadClaimTarget();
        if (s == bytes4(0x1e9a6950) || s == bytes4(0xb460af94) || s == bytes4(0xba087652)
            || s == bytes4(0x9343d9e1) || s == bytes4(0xcdac52ed) || s == bytes4(0x1e83409a)
            || s == bytes4(0x9ad82aa0) || s == bytes4(0x50b3f984)
            || s == bytes4(0xc9d2ff9d) || s == bytes4(0x2e1a7d4d)
            || s == bytes4(0x1338736f) || s == bytes4(0x6e553f65) || s == bytes4(0x94bf804d)) revert ForbiddenRewardsSelector();
        (bool ok,) = p.call{value: msg.value}(abi.encodeWithSelector(s, address(this), type(uint256).max));
        if (!ok) revert ClaimFailed();
    }

    function sweep(IERC20 token, address to) external nonReentrant {
        if (msg.sender != owner()) revert BadConverter();
        if (to != converter || converter == address(0)) revert BadConverter();
        if (isPrincipal[address(token)]) revert Principal();
        uint256 amt = token.balanceOf(address(this));
        if (amt == 0) revert BadClaimTarget();
        token.safeTransfer(to, amt);
        emit Swept(address(token), to, amt);
    }
}
