// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Arachnid CREATE2 factory. Same initcode + salt → same address on
///         every EVM that has the factory.
/// @dev This matches Orderly's identity model (ledger keys by address). It does
///      **not** replace LeafOFT wrap (that is one-chain custody + LZ mint).
///      hORDER is Arb-only and does **not** deploy twins. Keep this library for
///      a future listing that must appear as the same address on a second chain.
library LeafCreate2 {
    address internal constant FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    bytes32 internal constant HOLDER_SALT = keccak256("HyperLeaf.LeafOmnichainHolder.v1");
    bytes32 internal constant LOCKBOX_SALT = keccak256("HyperLeaf.LeafInboundLockbox.v1");

    function predict(bytes32 salt, bytes memory initCode) internal pure returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), FACTORY, salt, keccak256(initCode)))))
        );
    }
}
