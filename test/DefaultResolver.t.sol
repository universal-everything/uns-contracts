// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

import "forge-std/Test.sol";
import "../contracts/Resolver/DefaultResolver.sol";
import "../contracts/UNSRegistry/UNSRegistry.sol";

contract DefaultResolverTest is Test {
    DefaultResolver defaultResolver;
    UNSRegistry unsRegistry;

    function setUp() public {
        unsRegistry = new UNSRegistry(address(this));
        defaultResolver = new DefaultResolver(unsRegistry);
    }

    function testSetDataByRandomAddress() public {
        address random = address(0x123);
        bytes32 rootNode = bytes32(0);
        bytes32 dataKey = keccak256("dataKey");
        bytes memory dataValue = "someData";

        vm.prank(random);
        vm.expectRevert();
        defaultResolver.setData(rootNode, dataKey, dataValue);
    }

    function testSetDataByNameOwner() public {
        bytes32 rootNode = bytes32(0);
        bytes32 dataKey = keccak256("dataKey");
        bytes memory dataValue = "someData";
        defaultResolver.setData(rootNode, dataKey, dataValue);

        bytes memory retrievedData = defaultResolver.getData(rootNode, dataKey);
        assertEq(retrievedData, dataValue, "Data should match");
    }

    function testSetDataBatchByNameOwner() public {
        bytes32 rootNode = bytes32(0);
        bytes32[] memory dataKeys = new bytes32[](2);
        dataKeys[0] = keccak256("dataKey");
        dataKeys[1] = keccak256("dataKey2");
        bytes[] memory dataValues = new bytes[](2);
        dataValues[0] = "dataValue1";
        dataValues[1] = "dataValue2";
        defaultResolver.setDataBatch(rootNode, dataKeys, dataValues);

        bytes[] memory retrievedData = defaultResolver.getDataBatch(
            rootNode,
            dataKeys
        );
        assertEq(
            retrievedData[0],
            dataValues[0],
            "Data should match for key 1"
        );
        assertEq(
            retrievedData[1],
            dataValues[1],
            "Data should match for key 2"
        );
    }

    function testSetDataBatchByNameOwnerDifferentLength() public {
        bytes32 rootNode = bytes32(0);
        bytes32[] memory dataKeys = new bytes32[](2);
        dataKeys[0] = keccak256("dataKey");
        dataKeys[1] = keccak256("dataKey2");
        bytes[] memory dataValues = new bytes[](1);
        dataValues[0] = "dataValue1";

        vm.expectRevert();
        defaultResolver.setDataBatch(rootNode, dataKeys, dataValues);
    }

    function testSetDataBatchByNameOwnerZeroLength() public {
        bytes32 rootNode = bytes32(0);
        bytes32[] memory dataKeys = new bytes32[](0);
        bytes[] memory dataValues = new bytes[](0);

        vm.expectRevert();
        defaultResolver.setDataBatch(rootNode, dataKeys, dataValues);
    }

    function testClearRecords() public {
        bytes32 rootNode = bytes32(0);
        bytes32 dataKey = keccak256("dataKey");
        bytes memory dataValue = "someData";
        defaultResolver.setData(rootNode, dataKey, dataValue);

        bytes memory retrievedDataBefore = defaultResolver.getData(
            rootNode,
            dataKey
        );
        assertEq(retrievedDataBefore, dataValue, "Data should match");

        defaultResolver.clearRecords(rootNode);

        bytes memory retrievedDataAfter = defaultResolver.getData(
            rootNode,
            dataKey
        );
        assertEq(retrievedDataAfter.length, 0, "Data should be cleared");
    }

    function testSetDataByNameOwnerFromRegistry() public {
        bytes32 rootNode = bytes32(0);

        bytes32[] memory dataKeys = new bytes32[](2);
        dataKeys[0] = keccak256("dataKey");
        dataKeys[1] = keccak256("dataKey2");

        bytes[] memory dataValues = new bytes[](2);
        dataValues[0] = "dataValue1";
        dataValues[1] = "dataValue2";

        unsRegistry.setResolver(rootNode, address(defaultResolver));
        unsRegistry.setResolverData(rootNode, dataKeys, dataValues);

        bytes[] memory retrievedData = defaultResolver.getDataBatch(
            rootNode,
            dataKeys
        );
        assertEq(retrievedData[0], dataValues[0], "Data should match");
        assertEq(retrievedData[1], dataValues[1], "Data should match");

        bytes[] memory registryRetreivedData = unsRegistry.resolverData(
            rootNode,
            dataKeys
        );
        assertEq(registryRetreivedData[0], dataValues[0], "Data should match");
        assertEq(registryRetreivedData[1], dataValues[1], "Data should match");
    }

    function testSetDataByNameOwnerFor2NamesBatchCalls() public {
        bytes32 parentNameHash = bytes32(0); // Root name hash
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );

        unsRegistry.setSubNameOwner(
            parentNameHash,
            subNameLabelHash,
            address(this)
        );

        bytes32 dataKey = keccak256("dataKey");
        bytes memory dataValue = "someData";

        bytes memory setData1 = abi.encodeWithSignature(
            "setData(bytes32,bytes32,bytes)",
            parentNameHash,
            dataKey,
            dataValue
        );

        bytes memory setData2 = abi.encodeWithSignature(
            "setData(bytes32,bytes32,bytes)",
            subNameHash,
            dataKey,
            dataValue
        );

        bytes[] memory data = new bytes[](2);
        data[0] = setData1;
        data[1] = setData2;

        defaultResolver.batchCalls(data);

        bytes memory retrievedData1 = defaultResolver.getData(
            parentNameHash,
            dataKey
        );
        bytes memory retrievedData2 = defaultResolver.getData(
            subNameHash,
            dataKey
        );
        assertEq(retrievedData1, dataValue, "Data should match");
        assertEq(retrievedData2, dataValue, "Data should match");
    }

    function testSetDataByNonNameOwnerFor2NamesBatchCallsShouldRevert() public {
        bytes32 parentNameHash = bytes32(0); // Root name hash
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );

        bytes32 dataKey = keccak256("dataKey");
        bytes memory dataValue = "someData";

        bytes memory setData1 = abi.encodeWithSignature(
            "setData(bytes32,bytes32,bytes)",
            parentNameHash,
            dataKey,
            dataValue
        );

        bytes memory setData2 = abi.encodeWithSignature(
            "setData(bytes32,bytes32,bytes)",
            subNameHash,
            dataKey,
            dataValue
        );

        bytes[] memory data = new bytes[](2);
        data[0] = setData1;
        data[1] = setData2;

        vm.expectRevert();
        defaultResolver.batchCalls(data);
    }

    function testSetAuthorization() public {
        bytes32 node = bytes32(0);
        address target = address(0x789);

        bytes32 dataKey = keccak256("dataKey");
        bytes memory dataValue = "someData";

        vm.prank(target);
        vm.expectRevert();
        defaultResolver.setData(node, dataKey, dataValue);

        defaultResolver.setAuthorisation(node, target, true);

        vm.prank(target);
        defaultResolver.setData(node, dataKey, dataValue);
        bytes memory retrievedData = defaultResolver.getData(node, dataKey);
        assertEq(retrievedData, dataValue, "Data should match");
    }

    function testSetAuthorizationTurnOff() public {
        bytes32 node = bytes32(0);
        address target = address(0x789);

        bytes32 dataKey = keccak256("dataKey");
        bytes memory dataValue = "someData";

        vm.prank(target);
        vm.expectRevert();
        defaultResolver.setData(node, dataKey, dataValue);

        defaultResolver.setAuthorisation(node, target, true);

        vm.prank(target);
        defaultResolver.setData(node, dataKey, dataValue);
        bytes memory retrievedData = defaultResolver.getData(node, dataKey);
        assertEq(retrievedData, dataValue, "Data should match");

        defaultResolver.setAuthorisation(node, target, false);

        vm.prank(target);
        vm.expectRevert();
        defaultResolver.setData(node, dataKey, dataValue);
    }

    function testSetAuthorizationForAll() public {
        bytes32 parentNameHash = bytes32(0); // Root name hash
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );

        unsRegistry.setSubNameOwner(
            parentNameHash,
            subNameLabelHash,
            address(this)
        );

        address target = address(0x789);

        bytes32 dataKey = keccak256("dataKey");
        bytes memory dataValue = "someData";

        vm.prank(target);
        vm.expectRevert();
        defaultResolver.setData(parentNameHash, dataKey, dataValue);

        vm.prank(target);
        vm.expectRevert();
        defaultResolver.setData(subNameHash, dataKey, dataValue);

        defaultResolver.setAuthorisationForAll(target, true);

        vm.prank(target);
        defaultResolver.setData(parentNameHash, dataKey, dataValue);

        vm.prank(target);
        defaultResolver.setData(subNameHash, dataKey, dataValue);

        bytes memory retrievedData1 = defaultResolver.getData(
            parentNameHash,
            dataKey
        );
        bytes memory retrievedData2 = defaultResolver.getData(
            subNameHash,
            dataKey
        );

        assertEq(retrievedData1, dataValue, "Data should match");
        assertEq(retrievedData2, dataValue, "Data should match");
    }

    function testSetAuthorizationForAllTurnOff() public {
        bytes32 parentNameHash = bytes32(0); // Root name hash
        bytes32 subNameLabelHash = keccak256(abi.encodePacked("myname"));
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );

        unsRegistry.setSubNameOwner(
            parentNameHash,
            subNameLabelHash,
            address(this)
        );

        address target = address(0x789);

        bytes32 dataKey = keccak256("dataKey");
        bytes memory dataValue = "someData";

        vm.prank(target);
        vm.expectRevert();
        defaultResolver.setData(parentNameHash, dataKey, dataValue);

        vm.prank(target);
        vm.expectRevert();
        defaultResolver.setData(subNameHash, dataKey, dataValue);

        defaultResolver.setAuthorisationForAll(target, true);

        vm.prank(target);
        defaultResolver.setData(parentNameHash, dataKey, dataValue);

        vm.prank(target);
        defaultResolver.setData(subNameHash, dataKey, dataValue);

        bytes memory retrievedData1 = defaultResolver.getData(
            parentNameHash,
            dataKey
        );
        bytes memory retrievedData2 = defaultResolver.getData(
            subNameHash,
            dataKey
        );

        assertEq(retrievedData1, dataValue, "Data should match");
        assertEq(retrievedData2, dataValue, "Data should match");

        defaultResolver.setAuthorisationForAll(target, false);

        vm.prank(target);
        vm.expectRevert();
        defaultResolver.setData(parentNameHash, dataKey, dataValue);

        vm.prank(target);
        vm.expectRevert();
        defaultResolver.setData(subNameHash, dataKey, dataValue);
    }
}
