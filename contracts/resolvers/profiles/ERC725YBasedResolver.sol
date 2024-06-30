// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

import "./IERC725YBasedResolver.sol";
import "../ResolverBase.sol";

/// @title Default Resolver
/// @notice A simple resolver allowing the owner of a name to set its address and manage data.
abstract contract ERC725YBasedResolver is IERC725YBasedResolver, ResolverBase {
    /// @dev Stores the data for a name, keyed by version and data key.
    mapping(bytes32 => mapping(uint256 => mapping(bytes32 => bytes)))
        private _dataStore;

    /// @notice Retrieves data associated with a name and key.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) from which to retrieve data.
    /// @param dataKey The key corresponding to the data to retrieve.
    /// @return The data value associated with the given name and key.
    function getData(
        bytes32 nameHash,
        bytes32 dataKey
    ) external view returns (bytes memory) {
        uint256 recordsVersion = recordVersions[nameHash];
        return _getData(nameHash, recordsVersion, dataKey);
    }

    /// @notice Retrieves a batch of data values associated with a name and multiple keys.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) from which to retrieve data.
    /// @param dataKeys An array of keys corresponding to the data to retrieve.
    /// @return dataValues An array of data values for the given name and keys.
    function getDataBatch(
        bytes32 nameHash,
        bytes32[] memory dataKeys
    ) public view virtual returns (bytes[] memory dataValues) {
        dataValues = new bytes[](dataKeys.length);
        uint256 recordsVersion = recordVersions[nameHash];

        for (uint256 i = 0; i < dataKeys.length; ) {
            dataValues[i] = _getData(nameHash, recordsVersion, dataKeys[i]);

            // Increment the iterator in unchecked block to save gas
            unchecked {
                ++i;
            }
        }

        return dataValues;
    }

    /// @notice Sets data for a name and key.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) for which to set data.
    /// @param dataKey The key corresponding to the data to set.
    /// @param dataValue The value to set for the data.
    function setData(
        bytes32 nameHash,
        bytes32 dataKey,
        bytes memory dataValue
    ) external virtual authorised(nameHash) {
        uint256 recordsVersion = recordVersions[nameHash];
        _setData(nameHash, recordsVersion, dataKey, dataValue);
    }

    /// @notice Sets a batch of data for a name and multiple keys.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) for which to set data.
    /// @param dataKeys An array of keys corresponding to the data to set.
    /// @param dataValues An array of values to set for the data.
    function setDataBatch(
        bytes32 nameHash,
        bytes32[] memory dataKeys,
        bytes[] memory dataValues
    ) external virtual authorised(nameHash) {
        if (dataKeys.length != dataValues.length) {
            revert("Data keys and values lengths do not match");
        }

        if (dataKeys.length == 0) {
            revert("No data keys provided");
        }

        uint256 recordsVersion = recordVersions[nameHash];
        for (uint256 i = 0; i < dataKeys.length; ) {
            _setData(nameHash, recordsVersion, dataKeys[i], dataValues[i]);

            // Increment the iterator in unchecked block to save gas
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Retrieves data associated with a name on a specific version and key.
    function _getData(
        bytes32 nameHash,
        uint256 recordsVersion,
        bytes32 dataKey
    ) internal view virtual returns (bytes memory dataValue) {
        return _dataStore[nameHash][recordsVersion][dataKey];
    }

    /// @dev Sets data associated with a name on a specific version and key.
    function _setData(
        bytes32 nameHash,
        uint256 recordsVersion,
        bytes32 dataKey,
        bytes memory dataValue
    ) internal virtual {
        _dataStore[nameHash][recordsVersion][dataKey] = dataValue;
        emit DataChanged(nameHash, dataKey, dataValue);
    }
}
