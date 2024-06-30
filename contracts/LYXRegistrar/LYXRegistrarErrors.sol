// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

/// @notice Thrown when an attempt is made to interact with a name that has expired.
/// @param name The name that has expired.
error NameExpired(bytes32 name);

/// @notice Thrown when an attempt is made to register or interact with a name that is not available.
/// @param name The name that is not available.
error NameNotAvailable(bytes32 name);

/// @notice Thrown when an action is attempted outside the allowed renewal period for a name.
/// @param name The name for which the renewal period has ended.
error RenewalPeriodEnded(bytes32 name);

/// @notice Thrown when an attempt is made to burn a name too early in its lifecycle.
/// @param name The name attempted to be burned prematurely.
error CannotUnregisterYet(bytes32 name);

/// @notice Thrown when a provided label hash is not valid for the given data value.
/// @param label The invalid label hash.
/// @param dataValue The data value associated with the label hash.
error LabelHashIsNotValid(bytes32 label, bytes dataValue);

/// @notice Thrown when a function is called by an entity that is not a designated controller.
error CallerIsNotController();

/// @notice Thrown when a caller is not the NFT descriptor setter but attempts to change the NFT descriptor.
error NotNFTDescriptorSetter();

/// @notice Thrown when a caller is not the NFT descriptor setter but attempts to change the NFT descriptor setter.
error NotNFTDescriptorSetterSetter();
