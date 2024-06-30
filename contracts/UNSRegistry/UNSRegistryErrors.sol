// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

/// @notice Thrown when an unauthorized user attempts to perform an operation reserved for an authorized address of a name.
/// @param nameHash The nameHash of the name (according to the NameHash algorithm).
/// @param owner The current owner address of the name.
/// @param caller The address of the user who attempted the operation.
error UNSRegistry_NotAuthorized(
    bytes32 nameHash,
    address owner,
    address caller
);

/// @dev Error thrown when a batch call fails.
/// @notice This error indicates that one of the calls in a batch execution has failed.
/// @param index The index of the call in the batch that failed.
error UNSRegistry_BatchCallFailed(uint256 index);

/// @notice Error thrown when setting resolver data for unauthorized name.
/// @param nameHash The nameHash of the name (according to the NameHash algorithm).
/// @param _resolver The address of the current resolver for the name.
/// @param resolverData The resolver data to be set in the resolver.
error UNSRegistry_ChangingResolverDataDisallowed(
    bytes32 nameHash,
    address _resolver,
    bytes resolverData
);
