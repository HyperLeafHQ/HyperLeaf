// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library OptionsBuilder {
    uint16 internal constant TYPE_3 = 3;
    uint8 internal constant WORKER_EXECUTOR = 1;
    uint8 internal constant OPTION_TYPE_LZRECEIVE = 1;

    function lzReceiveOption(uint128 gas) internal pure returns (bytes memory) {
        return lzReceiveOption(gas, 0);
    }

    function lzReceiveOption(uint128 gas, uint128 value) internal pure returns (bytes memory) {
        bytes memory option =
            value == 0 ? abi.encodePacked(OPTION_TYPE_LZRECEIVE, gas) : abi.encodePacked(OPTION_TYPE_LZRECEIVE, gas, value);
        return abi.encodePacked(TYPE_3, WORKER_EXECUTOR, uint16(option.length), option);
    }
}
