// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// MockResolver for testing purposes
contract UNSRegistry_ResolverMock {
    // A mapping to store data values. The first key is the nameHash, and the second key is the data key.
    mapping(bytes32 => mapping(bytes32 => bytes)) public data;

    // Implementing setDataBatch from IDefaultResolver
    function setDataBatch(
        bytes32 nameHash,
        bytes32[] calldata keys,
        bytes[] calldata values
    ) external {
        require(
            keys.length == values.length,
            "Keys and values length mismatch"
        );
        for (uint i = 0; i < keys.length; i++) {
            data[nameHash][keys[i]] = values[i];
        }
    }

    // Implementing getData from IDefaultResolver
    function getData(
        bytes32 nameHash,
        bytes32 key
    ) external view returns (bytes memory) {
        return data[nameHash][key];
    }
}
