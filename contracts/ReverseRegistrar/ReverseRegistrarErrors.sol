// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

/// @notice Thrown when a function is called by an address that is not a controller.
/// @param caller The address that attempted to call the function.
error ReverseRegistrar_NotController(address caller);

/// @notice Thrown when an attempt is made to set a resolver to the zero address.
/// @dev Used to prevent setting a resolver to the zero address
error ReverseRegistrar_ResolverCannotBeZeroAddress();
