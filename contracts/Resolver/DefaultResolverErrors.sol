// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

// Error thrown when a function is called by an account other than an address authorized of a specified name.
/// @notice Thrown when an unauthorized user attempts to perform an operation reserved for an authorized address of a name.
/// @param nameHash The nameHash of the name (according to the NameHash algorithm).
/// @param caller The address of the user who attempted the operation.
error DefaultResolver_NotAuthorized(bytes32 nameHash, address caller);

/// @dev Error thrown when a batch call fails.
/// @notice This error indicates that one of the calls in a batch execution has failed.
/// @param index The index of the call in the batch that failed.
error DefaultResolver_BatchCallFailed(uint256 index);

/// @dev Error thrown when the lengths of `dataKeys` and `dataValues` arrays in `setDataBatch` function do not match.
/// @notice This error indicates a mismatch between the number of keys and values provided for setting data in batch.
error DefaultResolver_DataLengthMismatch();

/// @dev Error thrown when the `dataKeys` array in the `setDataBatch` function is empty.
/// @notice Indicates an attempt to perform a batch data update without any keys, which is not permissible.
error DefaultResolver_DataEmptyArray();
