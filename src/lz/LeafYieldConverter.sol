// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ILeafHypeRewarder} from "./ILeafHypeRewarder.sol";

interface ILeafConvertHalt {
    function converter() external view returns (address);
    function haltConvert() external;
}

/// @title LeafYieldConverter
/// @notice Custody for `pullYield`. Not an EOA. DEX / bridge are allowlisted
///         routes (Aerodrome, Relay, Portal, deBridge, Mayan, …). Each hop
///         reverts if `tokenOut` gained < `minOut`. Failed hop leaves inventory
///         here; keeper tries the next route. `notify` cannot credit more WHYPE
///         than this contract holds. Unsold tokens return only to a lockbox
///         that still points at this converter.
///         Wrap/redeem never call this contract.
contract LeafYieldConverter is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public keeper;
    address public guardian;
    ILeafHypeRewarder public rewarder;
    IERC20 public hype;
    bool public halted;
    uint16 public constant BPS = 10_000;
    /// @dev Max worse-than-last-fill the keeper may quote. Default 3%.
    uint16 public maxSlippageBps = 300;
    mapping(address tokenIn => mapping(address tokenOut => uint256)) public minPriceX18;
    mapping(address tokenIn => mapping(address tokenOut => uint256)) public lastPriceX18;

    mapping(address => bool) public isLockbox;
    mapping(address => bool) public isToken;
    mapping(address => bool) public isOutput;
    mapping(address => bool) public isRoute;

    event KeeperSet(address indexed keeper);
    event GuardianSet(address indexed guardian);
    event RewarderSet(address indexed rewarder, address indexed hype);
    event LockboxSet(address indexed lockbox, bool allowed);
    event TokenSet(address indexed token, bool allowed);
    event OutputSet(address indexed token, bool allowed);
    event RouteSet(address indexed route, bool allowed);
    event MinPriceSet(address indexed tokenIn, address indexed tokenOut, uint256 priceX18);
    event MaxSlippageSet(uint16 bps);
    event Halted(bool halted);
    event PullsHalted(address indexed lockbox);
    event Swapped(address indexed route, address indexed tokenIn, address indexed tokenOut, uint256 spent, uint256 got);
    event Bridged(address indexed route, address indexed tokenIn, uint256 spent);
    event Returned(address indexed lockbox, address indexed token, uint256 amount);
    event Notified(bytes32 indexed id, uint256 amount);

    error ZeroAddress();
    error NotKeeper();
    error NotGuardian();
    error HaltedErr();
    error BadRoute();
    error BadToken();
    error BadLockbox();
    error BelowMinOut(uint256 got, uint256 minOut);
    error SpentTooMuch();
    error NothingSpent();
    error RouteFailed();
    error NoRewarder();
    error SameToken();
    error Expired();

    modifier onlyKeeper() {
        if (msg.sender != keeper && msg.sender != owner()) revert NotKeeper();
        _;
    }

    constructor(address owner_, address keeper_, address guardian_) Ownable(owner_) {
        if (owner_ == address(0) || keeper_ == address(0) || guardian_ == address(0)) revert ZeroAddress();
        if (keeper_ == owner_) revert NotKeeper();
        keeper = keeper_;
        guardian = guardian_;
    }

    function setKeeper(address k) external onlyOwner {
        if (k == address(0) || k == owner()) revert ZeroAddress();
        keeper = k;
        emit KeeperSet(k);
    }

    function setGuardian(address g) external onlyOwner {
        if (g == address(0)) revert ZeroAddress();
        guardian = g;
        emit GuardianSet(g);
    }

    function setRewarder(address rewarder_, address hype_) external onlyOwner {
        if (rewarder_ == address(0) || hype_ == address(0)) revert ZeroAddress();
        rewarder = ILeafHypeRewarder(rewarder_);
        hype = IERC20(hype_);
        isToken[hype_] = true;
        isOutput[hype_] = true;
        emit RewarderSet(rewarder_, hype_);
    }

    function setLockbox(address box, bool ok) external onlyOwner {
        if (box == address(0)) revert ZeroAddress();
        isLockbox[box] = ok;
        emit LockboxSet(box, ok);
    }

    function setToken(address token, bool ok) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        isToken[token] = ok;
        emit TokenSet(token, ok);
    }

    function setOutput(address token, bool ok) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        isOutput[token] = ok;
        if (ok) isToken[token] = true;
        emit OutputSet(token, ok);
    }

    function setRoute(address route, bool ok) external onlyOwner {
        if (route == address(0) || route == address(this)) revert BadRoute();
        if (isLockbox[route]) revert BadRoute();
        isRoute[route] = ok;
        emit RouteSet(route, ok);
    }

    function setMaxSlippageBps(uint16 bps) external onlyOwner {
        if (bps == 0 || bps > 2_000) revert BelowMinOut(bps, 1);
        maxSlippageBps = bps;
        emit MaxSlippageSet(bps);
    }

    /// @notice Out-per-in × 1e18. Required before the first swap of a pair.
    ///         Lowering is the only way to accept a real market dump.
    function setMinPrice(address tokenIn, address tokenOut, uint256 priceX18) external onlyOwner {
        if (!isToken[tokenIn] || !isOutput[tokenOut] || priceX18 == 0) revert BadToken();
        minPriceX18[tokenIn][tokenOut] = priceX18;
        emit MinPriceSet(tokenIn, tokenOut, priceX18);
    }

    /// @notice Lowest minOut execute will accept. Floor from `minPriceX18`, plus
    ///         last fill × (1 − maxSlippageBps) so a 1-wei minOut cannot sandwich.
    function requiredMinOut(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {
        uint256 floor = minPriceX18[tokenIn][tokenOut];
        if (floor == 0 || amountIn == 0) revert BadToken();
        uint256 fromFloor = (amountIn * floor) / 1e18;
        uint256 last = lastPriceX18[tokenIn][tokenOut];
        uint256 fromLast;
        if (last > 0) {
            fromLast = (amountIn * last / 1e18) * (BPS - maxSlippageBps) / BPS;
        }
        return fromFloor > fromLast ? fromFloor : fromLast;
    }

    /// @notice Stop hops here and tell lockboxes to stop `pullYield`.
    function halt(address[] calldata boxes) external {
        if (msg.sender != owner() && msg.sender != keeper && msg.sender != guardian) revert NotGuardian();
        halted = true;
        emit Halted(true);
        uint256 n = boxes.length;
        for (uint256 i; i < n; ++i) {
            address box = boxes[i];
            if (!isLockbox[box]) revert BadLockbox();
            ILeafConvertHalt(box).haltConvert();
            emit PullsHalted(box);
        }
    }

    function unhalt() external onlyOwner {
        halted = false;
        emit Halted(false);
    }

    /// @notice Swap (`tokenOut` stays here) or bridge (`tokenOut` = 0, inventory leaves).
    ///         DEX, Relay, Portal, deBridge, Mayan are just allowlisted `route`s.
    ///         Caller `minOut` cannot go below `requiredMinOut`. Keeper still
    ///         required: bridge calldata has no floor, and `notify` picks listing.
    function execute(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minOut,
        address route,
        bytes calldata data,
        uint256 deadline
    ) external payable onlyKeeper nonReentrant {
        if (deadline < block.timestamp) revert Expired();
        if (halted) revert HaltedErr();
        if (!isRoute[route]) revert BadRoute();
        if (!isToken[address(tokenIn)] || amountIn == 0) revert BadToken();

        bool bridging = address(tokenOut) == address(0);
        if (!bridging) {
            if (address(tokenOut) == address(tokenIn)) revert SameToken();
            if (!isOutput[address(tokenOut)]) revert BadToken();
            uint256 floor = requiredMinOut(address(tokenIn), address(tokenOut), amountIn);
            if (minOut < floor) minOut = floor;
        }

        uint256 inBefore = tokenIn.balanceOf(address(this));
        if (inBefore < amountIn) revert BelowMinOut(inBefore, amountIn);
        uint256 outBefore = bridging ? 0 : tokenOut.balanceOf(address(this));

        tokenIn.forceApprove(route, amountIn);
        (bool ok,) = route.call{value: msg.value}(data);
        tokenIn.forceApprove(route, 0);
        if (!ok) revert RouteFailed();

        uint256 inAfter = tokenIn.balanceOf(address(this));
        if (inAfter > inBefore) revert SpentTooMuch();
        uint256 spent = inBefore - inAfter;
        if (spent > amountIn) revert SpentTooMuch();
        if (spent == 0) revert NothingSpent();

        if (bridging) {
            emit Bridged(route, address(tokenIn), spent);
            return;
        }

        uint256 outAfter = tokenOut.balanceOf(address(this));
        uint256 got = outAfter > outBefore ? outAfter - outBefore : 0;
        if (got < minOut) revert BelowMinOut(got, minOut);
        lastPriceX18[address(tokenIn)][address(tokenOut)] = (got * 1e18) / spent;
        emit Swapped(route, address(tokenIn), address(tokenOut), spent, got);
    }

    /// @notice WHYPE already here (HyperEVM). Cannot notify more than balance,
    ///         cannot notify below `minAmount` (keeper quote / `minNotify`).
    function notify(bytes32 id, uint256 amount, uint256 minAmount) external onlyKeeper nonReentrant {
        if (address(rewarder) == address(0) || address(hype) == address(0)) revert NoRewarder();
        if (amount < minAmount) revert BelowMinOut(amount, minAmount);
        uint256 bal = hype.balanceOf(address(this));
        if (amount > bal) revert BelowMinOut(amount, bal);
        hype.forceApprove(address(rewarder), amount);
        rewarder.notify(id, amount);
        hype.forceApprove(address(rewarder), 0);
        emit Notified(id, amount);
    }

    /// @notice Unsold inventory goes home. Never to an EOA.
    function returnToLockbox(address lockbox, IERC20 token, uint256 amount) external onlyKeeper nonReentrant {
        if (!isLockbox[lockbox]) revert BadLockbox();
        if (ILeafConvertHalt(lockbox).converter() != address(this)) revert BadLockbox();
        if (!isToken[address(token)] || amount == 0) revert BadToken();
        token.safeTransfer(lockbox, amount);
        emit Returned(lockbox, address(token), amount);
    }

    function sweepNative() external onlyOwner {
        (bool ok,) = owner().call{value: address(this).balance}("");
        if (!ok) revert RouteFailed();
    }

    receive() external payable {}
}
