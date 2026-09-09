// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LeafForbiddenSelectors} from "./LeafForbiddenSelectors.sol";

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
    mapping(address => bytes32) public claimDataHash;
    address public converter;
    address public principal;
    bytes4 public rewardsSelector;

    error ZeroAddress();
    error NotAdapter();
    error BadClaimTarget();
    error BadClaimSelector();
    error ClaimFailed();
    error Principal();
    error NotPrincipal();
    error ForbiddenRewardsSelector();
    error BadConverter();

    event AdapterSet(address indexed adapter, bool allowed);
    event PrincipalSet(address indexed token, bool ok);
    event ClaimTargetSet(address indexed target, bool allowed);
    event ClaimCallSet(address indexed target, bytes4 selector, bytes32 dataHash);
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
        if (ok) {
            address prev = principal;
            if (prev != address(0) && prev != t) {
                isPrincipal[prev] = false;
                emit PrincipalSet(prev, false);
            }
            principal = t;
            isPrincipal[t] = true;
        } else {
            isPrincipal[t] = false;
            if (principal == t) principal = address(0);
        }
        emit PrincipalSet(t, ok);
    }

    function setClaimTarget(address t, bool ok) external onlyOwner {
        if (t == address(0) || isPrincipal[t]) revert BadClaimTarget();
        claimTarget[t] = ok;
        if (!ok) {
            claimSelector[t] = bytes4(0);
            claimDataHash[t] = bytes32(0);
        }
        emit ClaimTargetSet(t, ok);
    }

    /// @notice Selector-only config. Pins calldata to the selector bytes, so it
    ///         is safe only for zero-argument calls.
    function setClaimCall(address t, bytes4 selector) external onlyOwner {
        if (t == address(0) || isPrincipal[t] || selector == bytes4(0)) revert BadClaimTarget();
        claimTarget[t] = true;
        claimSelector[t] = selector;
        claimDataHash[t] = keccak256(abi.encodePacked(selector));
        emit ClaimCallSet(t, selector, claimDataHash[t]);
    }

    /// @notice Preferred: pin the entire calldata blob, including parameters.
    function setClaimCall(address t, bytes calldata data) external onlyOwner {
        if (t == address(0) || isPrincipal[t] || data.length < 4) revert BadClaimTarget();
        bytes4 selector = bytes4(data[0:4]);
        claimTarget[t] = true;
        claimSelector[t] = selector;
        claimDataHash[t] = keccak256(data);
        emit ClaimCallSet(t, selector, claimDataHash[t]);
    }

    function setConverter(address c) external onlyOwner {
        if (c == address(0)) revert ZeroAddress();
        converter = c;
        emit ConverterSet(c);
    }

    function setRewardsSelector(bytes4 s) external onlyOwner {
        if (s != bytes4(0) && LeafForbiddenSelectors.forbidden(s)) revert ForbiddenRewardsSelector();
        rewardsSelector = s;
        emit RewardsSelectorSet(s);
    }

    function release(IERC20 token, address to, uint256 amount) external nonReentrant {
        if (!isAdapter[msg.sender]) revert NotAdapter();
        if (address(token) != principal) revert NotPrincipal();
        token.safeTransfer(to, amount);
        emit Released(address(token), to, amount);
    }

    function pokeClaim(address t, bytes calldata data) external payable nonReentrant {
        if (!claimTarget[t] || isPrincipal[t] || data.length < 4) revert BadClaimTarget();
        if (
            claimSelector[t] == bytes4(0) || bytes4(data[0:4]) != claimSelector[t]
                || keccak256(data) != claimDataHash[t]
        ) revert BadClaimSelector();
        (bool ok,) = t.call{value: msg.value}(data);
        if (!ok) revert ClaimFailed();
    }

    /// @notice Squid claimRewards(this, max). Selector is not redeem.
    function pokeRewards() external payable nonReentrant {
        address p = principal;
        bytes4 s = rewardsSelector;
        if (p == address(0) || s == bytes4(0)) revert BadClaimTarget();
        if (LeafForbiddenSelectors.forbidden(s)) revert ForbiddenRewardsSelector();
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
