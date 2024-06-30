// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

/// @dev Thrown when an operation is attempted on a locked Top-Level Domain (TLD).
/// @param nameHash The label hash of the locked TLD that triggered the error.
error RootRegistrar_NameIsLocked(bytes32 nameHash);

/// @notice Thrown when a function is called by an address that is not a controller.
/// @param caller The address that attempted to call the function.
error RootRegistrar_NotController(address caller);
