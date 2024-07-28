// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/UNSRegistry/UNSRegistry.sol";
import "../contracts/UNSRegistry/IUNSRegistry.sol";
import "./Mocks/UNSRegistry_ResolverMock.sol";

contract UNSRegistryTest is Test {
    UNSRegistry registry;

    /// @notice Emitted when the owner of a name is changed.
    /// @param nameHash The nameHash that was updated.
    /// @param newOwner The new owner of the name.
    event OwnerChanged(bytes32 indexed nameHash, address newOwner);

    /// @notice Emitted when the resolver for a name is changed.
    /// @param nameHash The nameHash that was updated.
    /// @param newResolver The new resolver of the name.
    event ResolverChanged(bytes32 indexed nameHash, address newResolver);

    /// @notice Emitted when the TTL of a name is changed.
    /// @param nameHash The nameHash that was updated.
    /// @param newTTL The updated Time to Live (TTL) value.
    event TTLChanged(bytes32 indexed nameHash, uint64 newTTL);

    /// @notice Emitted when the owner of a name is changed.
    /// @param nameHash The nameHash that was updated.
    /// @param newOwner The new owner of the name.
    event SubnNameOwnerChanged(
        bytes32 indexed nameHash,
        bytes32 indexed label,
        address newOwner
    );

    /// @notice Emitted when the owner of a name approves or revokes a new operator
    /// @param owner The address of the owner granting or revoking permission
    /// @param operator The address of the operator being approved or revoked
    /// @param approved Boolean status of the approval (true if approved, false if revoked)
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function setUp() public {
        registry = new UNSRegistry(address(this));
    }

    function testConstructorInitializesRootRecord() public {
        bytes32 rootNameHash = bytes32(0);
        IUNSRegistry.Record memory record = registry.record(rootNameHash);

        assertEq(record.owner, address(this));
        assertEq(record.resolver, address(0));
        assertEq(record.ttl, 0);
    }

    function testSetRecordByRootOwner() public {
        bytes32 rootNameHash = bytes32(0); // Root name hash
        address newOwner = address(0x2);
        address newResolver = address(0x3);
        uint64 newTTL = 3600;

        // Act
        vm.expectEmit(true, true, true, true);
        emit OwnerChanged(rootNameHash, newOwner);
        vm.expectEmit(true, true, true, true);
        emit ResolverChanged(rootNameHash, newResolver);
        vm.expectEmit(true, true, true, true);
        emit TTLChanged(rootNameHash, newTTL);

        registry.setRecord(rootNameHash, newOwner, newResolver, newTTL);

        // Check the record
        IUNSRegistry.Record memory record = registry.record(rootNameHash);
        assertEq(record.owner, newOwner, "Owner should be updated");
        assertEq(record.resolver, newResolver, "Resolver should be updated");
        assertEq(record.ttl, newTTL, "TTL should be updated");
    }

    function testSetRecordByOperator() public {
        // Arrange
        bytes32 rootNameHash = bytes32(0); // Root name hash
        address operator = address(0x2);
        address newOwner = address(0x3);
        address newResolver = address(0x4);
        uint64 newTTL = 3600;

        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(address(this), operator, true);
        // Set operator as approved for all for the root owner
        registry.setApprovalForAll(operator, true);

        // Use the operator to act on behalf of the root owner
        vm.prank(operator);
        registry.setRecord(rootNameHash, newOwner, newResolver, newTTL);

        // Assert
        // Check the record
        IUNSRegistry.Record memory record = registry.record(rootNameHash);
        assertEq(record.owner, newOwner, "Owner should be updated");
        assertEq(record.resolver, newResolver, "Resolver should be updated");
        assertEq(record.ttl, newTTL, "TTL should be updated");
    }

    function testSetRecordByUnauthorizedUserShouldFail() public {
        bytes32 rootNameHash = bytes32(0); // Root name hash
        address unauthorizedUser = address(0x5);
        address newOwner = address(0x6);
        address newResolver = address(0x7);
        uint64 newTTL = 3600;

        // Attempt to set a record by an unauthorized user
        vm.prank(unauthorizedUser);

        // Expect the transaction to revert
        vm.expectRevert();
        registry.setRecord(rootNameHash, newOwner, newResolver, newTTL);
    }

    function testSetOwnerByRootOwner() public {
        bytes32 rootNameHash = bytes32(0); // Root name hash
        address newOwner = address(0x2);

        // Act
        registry.setOwner(rootNameHash, newOwner);

        // Check the owner
        IUNSRegistry.Record memory record = registry.record(rootNameHash);
        assertEq(record.owner, newOwner, "Owner should be updated");
    }

    function testSetResolverByRootOwner() public {
        bytes32 rootNameHash = bytes32(0); // Root name hash
        address newResolver = address(0x3);

        // Act
        registry.setResolver(rootNameHash, newResolver);

        // Check the resolver
        IUNSRegistry.Record memory record = registry.record(rootNameHash);
        assertEq(record.resolver, newResolver, "Resolver should be updated");
    }

    function testSetTTLByRootOwner() public {
        bytes32 rootNameHash = bytes32(0); // Root name hash
        uint64 newTTL = 3600;

        // Act
        registry.setTTL(rootNameHash, newTTL);

        // Check the TTL
        IUNSRegistry.Record memory record = registry.record(rootNameHash);
        assertEq(record.ttl, newTTL, "TTL should be updated");
    }

    function testSetResolverData() public {
        // Define the name hash and resolver data
        bytes32 nameHash = bytes32(0); // Example nameHash
        address mockResolver = address(new UNSRegistry_ResolverMock()); // Example mock resolver
        bytes32[] memory dataKeys = new bytes32[](2);
        dataKeys[0] = keccak256("key1");
        dataKeys[1] = keccak256("key2");
        bytes[] memory dataValues = new bytes[](2);
        dataValues[0] = "value1";
        dataValues[1] = "value2";

        bytes[] memory resolverData = new bytes[](1);
        resolverData[0] = abi.encodeWithSelector(
            UNSRegistry_ResolverMock.setDataBatch.selector,
            nameHash,
            dataKeys,
            dataValues
        );

        // Set the resolver for the nameHash
        registry.setResolver(nameHash, mockResolver);

        // Act
        registry.setResolverData(nameHash, resolverData);

        // Verify the data
        for (uint i = 0; i < dataKeys.length; i++) {
            bytes memory actualValue = UNSRegistry_ResolverMock(mockResolver)
                .getData(nameHash, dataKeys[i]);
            assertEq(actualValue, dataValues[i], "Data value should match");
        }
    }

    function testSetRecordWithResolverData() public {
        bytes32 nameHash = bytes32(0); // Root name hash for this example
        address newOwner = address(0x2);
        address newResolver = address(new UNSRegistry_ResolverMock());
        uint64 newTTL = 3600;

        bytes32[] memory resolverDataKeys = new bytes32[](1);
        resolverDataKeys[0] = keccak256(abi.encodePacked("key"));

        bytes[] memory resolverDataValues = new bytes[](1);
        resolverDataValues[0] = abi.encodePacked("value");

        bytes[] memory resolverData = new bytes[](1);
        resolverData[0] = abi.encodeWithSelector(
            UNSRegistry_ResolverMock.setDataBatch.selector,
            nameHash,
            resolverDataKeys,
            resolverDataValues
        );

        // Act
        registry.setRecordWithResolverData(
            nameHash,
            newOwner,
            newResolver,
            newTTL,
            resolverData
        );

        // Check the record
        IUNSRegistry.Record memory record = registry.record(nameHash);
        assertEq(record.owner, newOwner, "Owner should be updated");
        assertEq(record.resolver, newResolver, "Resolver should be updated");
        assertEq(record.ttl, newTTL, "TTL should be updated");

        // Check resolver data
        bytes memory storedData = UNSRegistry_ResolverMock(newResolver).getData(
            nameHash,
            resolverDataKeys[0]
        );
        assertEq(
            storedData,
            resolverDataValues[0],
            "Resolver data should be updated"
        );
    }

    function testSetSubNameRecord() public {
        bytes32 parentNameHash = bytes32(0); // Root name hash
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );

        address newOwner = address(0x123);
        address newResolver = address(0x456);
        uint64 newTTL = 3600;

        registry.setSubNameRecord(
            parentNameHash,
            subNameLabelHash,
            newOwner,
            newResolver,
            newTTL
        );

        IUNSRegistry.Record memory record = registry.record(subNameHash);
        assertEq(record.owner, newOwner);
        assertEq(record.resolver, newResolver);
        assertEq(record.ttl, newTTL);
    }

    function testSetSubNameRecordWithResolverData() public {
        bytes32 parentNameHash = bytes32(0); // Root name hash
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );

        address newOwner = address(0x123);
        address newResolver = address(new UNSRegistry_ResolverMock());
        uint64 newTTL = 3600;

        bytes32[] memory resolverDataKeys = new bytes32[](1);
        resolverDataKeys[0] = keccak256(abi.encodePacked("key"));

        bytes[] memory resolverDataValues = new bytes[](1);
        resolverDataValues[0] = abi.encodePacked("value");

        bytes[] memory resolverData = new bytes[](1);
        resolverData[0] = abi.encodeWithSelector(
            UNSRegistry_ResolverMock.setDataBatch.selector,
            subNameHash,
            resolverDataKeys,
            resolverDataValues
        );

        registry.setSubNameRecordWithResolverData(
            parentNameHash,
            subNameLabelHash,
            newOwner,
            newResolver,
            newTTL,
            resolverData
        );

        IUNSRegistry.Record memory record = registry.record(subNameHash);
        assertEq(record.owner, newOwner);
        assertEq(record.resolver, newResolver);
        assertEq(record.ttl, newTTL);
        bytes memory storedData = UNSRegistry_ResolverMock(newResolver).getData(
            subNameHash,
            resolverDataKeys[0]
        );
        assertEq(
            storedData,
            resolverDataValues[0],
            "Resolver data should be updated"
        );
    }

    function testSetSubNameOwner() public {
        bytes32 parentNameHash = bytes32(0); // Root name hash
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );
        address newOwner = address(0x789);

        vm.expectEmit(true, true, true, true);
        emit SubnNameOwnerChanged(parentNameHash, subNameLabelHash, newOwner);
        registry.setSubNameOwner(parentNameHash, subNameLabelHash, newOwner);

        IUNSRegistry.Record memory record = registry.record(subNameHash);
        assertEq(record.owner, newOwner, "Owner should be updated");
    }

    function testSetSubNameResolver() public {
        bytes32 parentNameHash = bytes32(0); // Root name hash
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );
        address newResolver = address(new UNSRegistry_ResolverMock());

        vm.expectEmit(true, true, true, true);
        emit ResolverChanged(subNameHash, newResolver);
        registry.setSubNameResolver(
            parentNameHash,
            subNameLabelHash,
            newResolver
        );

        IUNSRegistry.Record memory record = registry.record(subNameHash);
        assertEq(record.resolver, newResolver, "Resolver should be updated");
    }

    function testSetSubNameTTL() public {
        bytes32 parentNameHash = bytes32(0); // Root name hash
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );
        uint64 newTTL = 7200;

        vm.expectEmit(true, true, true, true);
        emit TTLChanged(subNameHash, newTTL);
        registry.setSubNameTTL(parentNameHash, subNameLabelHash, newTTL);

        IUNSRegistry.Record memory record = registry.record(subNameHash);
        assertEq(record.ttl, newTTL, "TTL should be updated");
    }

    function testSetSubNameResolverData() public {
        bytes32 parentNameHash = bytes32(0); // Root name hash
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );
        address newResolver = address(new UNSRegistry_ResolverMock());

        registry.setSubNameResolver(
            parentNameHash,
            subNameLabelHash,
            newResolver
        );

        bytes32[] memory resolverDataKeys = new bytes32[](1);
        resolverDataKeys[0] = keccak256(abi.encodePacked("key"));

        bytes[] memory resolverDataValues = new bytes[](1);
        resolverDataValues[0] = abi.encodePacked("value");

        bytes[] memory resolverData = new bytes[](1);
        resolverData[0] = abi.encodeWithSelector(
            UNSRegistry_ResolverMock.setDataBatch.selector,
            subNameHash,
            resolverDataKeys,
            resolverDataValues
        );

        registry.setSubNameResolverData(
            parentNameHash,
            subNameLabelHash,
            resolverData
        );

        bytes memory storedData = UNSRegistry_ResolverMock(newResolver).getData(
            subNameHash,
            resolverDataKeys[0]
        );
        assertEq(
            storedData,
            resolverDataValues[0],
            "Resolver data should be updated"
        );
    }

    // Test for successful batchCalls execution
    function testSuccessfulBatchCalls() public {
        bytes32 parentNameHash = bytes32(0);
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );
        address newOwner = address(0x123);
        address newResolver = address(0x456);
        uint64 newTTL = 3600;

        bytes memory setOwnerData = abi.encodeWithSignature(
            "setSubNameOwner(bytes32,bytes32,address)",
            parentNameHash,
            subNameLabelHash,
            newOwner
        );

        bytes memory setResolverData = abi.encodeWithSignature(
            "setSubNameResolver(bytes32,bytes32,address)",
            parentNameHash,
            subNameLabelHash,
            newResolver
        );

        bytes memory setTTLData = abi.encodeWithSignature(
            "setSubNameTTL(bytes32,bytes32,uint64)",
            parentNameHash,
            subNameLabelHash,
            newTTL
        );

        bytes[] memory data = new bytes[](3);
        data[0] = setOwnerData;
        data[1] = setResolverData;
        data[2] = setTTLData;

        registry.batchCalls(data);

        // Assertions to verify successful execution
        assertEq(registry.record(subNameHash).owner, newOwner);
        assertEq(registry.record(subNameHash).resolver, newResolver);
        assertEq(registry.record(subNameHash).ttl, newTTL);
    }

    // Test for failed batchCalls execution
    function testToRevertBatchCalls() public {
        bytes32 parentNameHash = bytes32(0);
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        address newOwner = address(0x123);
        address newResolver = address(0x456);
        address operator = address(0x789);

        bytes memory setOwnerData = abi.encodeWithSignature(
            "setSubNameOwner(bytes32,bytes32,address)",
            parentNameHash,
            subNameLabelHash,
            newOwner
        );

        bytes memory setResolverData = abi.encodeWithSignature(
            "setSubNameResolver(bytes32,bytes32,address)",
            parentNameHash,
            subNameLabelHash,
            newResolver
        );

        bytes[] memory data = new bytes[](3);
        data[0] = setOwnerData;
        data[1] = setResolverData;

        // Expecting the batch call to fail
        vm.prank(operator);
        vm.expectRevert();
        registry.batchCalls(data);
    }
}
