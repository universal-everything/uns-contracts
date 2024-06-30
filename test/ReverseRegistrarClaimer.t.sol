// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

import "forge-std/Test.sol";
import "../contracts/ReverseRegistrar/ReverseRegistrar.sol";
import "../contracts/ReverseRegistrar/ReverseContractClaimer.sol";
import "../contracts/UNSRegistry/UNSRegistry.sol";
import "../contracts/Resolver/DefaultResolver.sol";

contract ReverseRegistrarClaimerTest is Test {
    ReverseRegistrar reverseRegistrar;
    UNSRegistry unsRegistry;
    DefaultResolver defaultResolver;
    ReverseRegistrarContractClaimer reverseRegistrarClaimer;

    function setUp() public {
        unsRegistry = new UNSRegistry(address(this));
        defaultResolver = new DefaultResolver(unsRegistry);
        reverseRegistrar = new ReverseRegistrar(
            address(unsRegistry),
            address(defaultResolver)
        );

        unsRegistry.setSubNameOwner(
            bytes32(0),
            keccak256(abi.encodePacked("reverse")),
            address(this)
        );
        unsRegistry.setSubNameOwner(
            0xa097f6721ce401e757d1223a763fef49b8b5f90bb18567ddb86fd205dff71d34,
            keccak256(abi.encodePacked("addr")),
            address(reverseRegistrar)
        );
    }

    function testReverseClaimerInitialization() public {
        reverseRegistrarClaimer = new ReverseRegistrarContractClaimer(
            unsRegistry,
            address(this)
        );

        address reverseOwner = unsRegistry.owner(
            node(address(reverseRegistrarClaimer))
        );
        assertEq(
            reverseOwner,
            address(this),
            "Reverse owner should match claimant address"
        );
    }

    // Helpers

    bytes32 constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    bytes32 constant lookup =
        0x3031323334353637383961626364656600000000000000000000000000000000;

    /// @notice Computes the node hash for a given account's reverse records.
    /// @dev Returns the node hash for a specific address.
    /// @param addr The address to compute the node hash for.
    /// @return The node hash.
    function node(address addr) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(addr))
            );
    }

    /// @dev Computes the SHA3 hash of the lower-case hexadecimal representation of an Ethereum address.
    /// @param addr The address to hash.
    /// @return ret The SHA3 hash of the lower-case hexadecimal encoding of the input address.
    function sha3HexAddress(address addr) internal pure returns (bytes32 ret) {
        assembly {
            for {
                let i := 40
            } gt(i, 0) {

            } {
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }

            ret := keccak256(0, 40)
        }
    }
}

contract MockOwnable {
    address _ownerVariable;

    function setOwner(address addr) public {
        _ownerVariable = addr;
    }

    function owner() public returns (address) {
        return _ownerVariable;
    }
}
