// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

/// @title IERC725YBasedResolver Interface
/// @notice Provides an interface for managing data and authorization settings on names.
interface IERC725YBasedResolver {
    /// @notice Emitted when data associated with a name is changed.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @param dataKey The key corresponding to the data that was changed.
    /// @param dataValue The new value of the data.
    event DataChanged(
        bytes32 indexed nameHash,
        bytes32 indexed dataKey,
        bytes dataValue
    );

    /// @notice Retrieves data associated with a name and key.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) from which to retrieve data.
    /// @param dataKey The key corresponding to the data to retrieve.
    /// @return The data value associated with the given name and key.
    function getData(
        bytes32 nameHash,
        bytes32 dataKey
    ) external view returns (bytes memory);

    /// @notice Retrieves a batch of data values associated with a name and multiple keys.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) from which to retrieve data.
    /// @param dataKeys An array of keys corresponding to the data to retrieve.
    /// @return dataValues An array of data values for the given name and keys.
    function getDataBatch(
        bytes32 nameHash,
        bytes32[] memory dataKeys
    ) external view returns (bytes[] memory dataValues);

    /// @notice Sets data for a name and key.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) for which to set data.
    /// @param dataKey The key corresponding to the data to set.
    /// @param dataValue The value to set for the data.
    function setData(
        bytes32 nameHash,
        bytes32 dataKey,
        bytes memory dataValue
    ) external;

    /// @notice Sets a batch of data for a name and multiple keys.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) for which to set data.
    /// @param dataKeys An array of keys corresponding to the data to set.
    /// @param dataValues An array of values to set for the data.
    function setDataBatch(
        bytes32 nameHash,
        bytes32[] memory dataKeys,
        bytes[] memory dataValues
    ) external;
}
