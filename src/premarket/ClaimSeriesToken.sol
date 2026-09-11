// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Clone target. Plain ERC-20. Mint/burn: factory only.
contract ClaimSeriesToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    address public factory;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    error NotFactory();
    error AlreadyInit();
    error ZeroAddress();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function initialize(address factory_, string memory name_, string memory symbol_) external {
        if (factory != address(0)) revert AlreadyInit();
        if (factory_ == address(0)) revert ZeroAddress();
        factory = factory_;
        name = name_;
        symbol = symbol_;
    }

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    function mint(address to, uint256 amount) external onlyFactory {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external onlyFactory {
        uint256 b = balanceOf[from];
        require(b >= amount, "bal");
        unchecked {
            balanceOf[from] = b - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (msg.sender != factory) {
            uint256 a = allowance[from][msg.sender];
            if (a != type(uint256).max) {
                require(a >= amount, "allow");
                unchecked {
                    allowance[from][msg.sender] = a - amount;
                }
            }
        }
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        uint256 b = balanceOf[from];
        require(b >= amount, "bal");
        unchecked {
            balanceOf[from] = b - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}
