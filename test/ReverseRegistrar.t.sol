// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

import "forge-std/Test.sol";
import "../contracts/ReverseRegistrar/ReverseRegistrar.sol";
import "../contracts/UNSRegistry/UNSRegistry.sol";
import "../contracts/Resolver/DefaultResolver.sol";

contract ReverseRegistrarTest is Test {
    ReverseRegistrar reverseRegistrar;
    UNSRegistry unsRegistry;
    DefaultResolver defaultResolver;

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

    function testClaim() public {
        address owner = address(this);

        reverseRegistrar.claim(owner);

        address resolver = unsRegistry.resolver(node(owner));
        address reverseOwner = unsRegistry.owner(node(owner));

        assertEq(reverseOwner, owner, "Reverse owner should match");
        assertEq(
            resolver,
            address(defaultResolver),
            "Resolver should match default resolver"
        );
    }

    function testClaimWithResolver() public {
        address owner = address(this);
        address resolver = address(0x123);

        reverseRegistrar.claimWithResolver(owner, resolver);
        address retrievedResolver = unsRegistry.resolver(node(owner));
        address reverseOwner = unsRegistry.owner(node(address(this)));

        assertEq(reverseOwner, owner, "Reverse owner should match");
        assertEq(
            retrievedResolver,
            resolver,
            "Resolver should match specified resolver"
        );
    }

    function testClaimForAddr() public {
        address owner = address(this);

        bytes32 returnedNode = reverseRegistrar.claimForAddr(
            owner,
            owner,
            address(defaultResolver)
        );
        address resolver = unsRegistry.resolver(node(owner));
        address reverseOwner = unsRegistry.owner(node(owner));

        assertEq(
            returnedNode,
            node(owner),
            "Reverse node should equal to the return value"
        );
        assertEq(reverseOwner, owner, "Reverse owner should match");
        assertEq(
            resolver,
            address(defaultResolver),
            "Resolver should match default resolver"
        );
    }

    function testClaimForAddrWithResolverData() public {
        address owner = address(this);

        bytes32[] memory resolverDataKeys = new bytes32[](1);
        resolverDataKeys[0] = bytes32("key");
        bytes[] memory resolverDataValues = new bytes[](1);
        resolverDataValues[0] = abi.encodePacked("value");

        bytes32 reverseNode = reverseRegistrar.claimForAddrWithResolverData(
            owner,
            owner,
            address(defaultResolver),
            resolverDataKeys,
            resolverDataValues
        );

        address retrievedResolver = unsRegistry.resolver(reverseNode);
        address reverseOwner = unsRegistry.owner(reverseNode);
        assertEq(reverseOwner, owner, "Reverse owner should match");
        assertEq(
            retrievedResolver,
            address(defaultResolver),
            "Resolver should match specified resolver"
        );

        // Retrieve resolver data and verify
        bytes memory retrievedData = defaultResolver.getData(
            reverseNode,
            resolverDataKeys[0]
        );
        assertEq(
            retrievedData,
            resolverDataValues[0],
            "Resolver data should match"
        );
    }

    function testClaimWithDifferentAddressShouldFail() public {
        address owner = address(this);
        address otherAddress = address(0x1);

        vm.expectRevert();
        reverseRegistrar.claimForAddr(
            otherAddress,
            owner,
            address(defaultResolver)
        );
    }

    function testControllerClaimForDifferentAddress() public {
        address owner = address(this);
        address controller = address(0x2);
        reverseRegistrar.addController(controller);

        address addr = address(0x789);
        vm.prank(controller);
        reverseRegistrar.claimForAddr(addr, owner, address(defaultResolver));

        address resolver = unsRegistry.resolver(node(addr));
        address reverseOwner = unsRegistry.owner(node(addr));
        assertEq(
            reverseOwner,
            owner,
            "Reverse owner should match controller address"
        );
        assertEq(
            resolver,
            address(defaultResolver),
            "Resolver should match default resolver"
        );
    }

    function testApprovedAddressClaimForDifferentAddress() public {
        address approvedAddress = address(0x3);

        unsRegistry.setApprovalForAll(approvedAddress, true);

        vm.prank(approvedAddress);
        reverseRegistrar.claimForAddr(
            address(this),
            approvedAddress,
            address(defaultResolver)
        );

        address resolver = unsRegistry.resolver(node(address(this)));
        address reverseOwner = unsRegistry.owner(node(address(this)));
        assertEq(
            reverseOwner,
            approvedAddress,
            "Reverse owner should match approved address"
        );
        assertEq(
            resolver,
            address(defaultResolver),
            "Resolver should match default resolver"
        );
    }

    function testContractOwnerClaimForAddress() public {
        address _addr = address(0x3);

        address ownableContract = address(new MockOwnable());
        MockOwnable(ownableContract).setOwner(_addr);

        vm.prank(_addr);
        reverseRegistrar.claimForAddr(
            ownableContract,
            _addr,
            address(defaultResolver)
        );

        address resolver = unsRegistry.resolver(node(ownableContract));
        address reverseOwner = unsRegistry.owner(node(ownableContract));
        assertEq(
            reverseOwner,
            _addr,
            "Reverse owner should match approved address"
        );
        assertEq(
            resolver,
            address(defaultResolver),
            "Resolver should match default resolver"
        );
    }

    function testNode() public {
        address addr = address(this);
        bytes32 computedNode = reverseRegistrar.node(addr);
        bytes32 expectedNode = keccak256(
            abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(addr))
        );
        assertEq(
            computedNode,
            expectedNode,
            "Computed node should match expected node"
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
