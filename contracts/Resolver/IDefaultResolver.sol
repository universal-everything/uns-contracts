// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

/// @title IDefaultResolver Interface
/// @notice Provides an interface for managing data and authorization settings on names.
interface IDefaultResolver {
    /// @notice Emitted when the authorisation status for a specific target and name is updated.
    /// @param owner The owner of the name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm)
    ///        whose authorization settings are being changed.
    /// @param target The address of the entity receiving authorization changes.
    /// @param isAuthorised The updated authorization status.
    event AuthorisationChanged(
        address indexed owner,
        bytes32 indexed nameHash,
        address indexed target,
        bool isAuthorised
    );

    /// @notice Emitted when the global authorisation status for a target is updated.
    /// @param owner The owner setting the authorization.
    /// @param target The address of the entity receiving global authorization changes.
    /// @param isAuthorised The updated global authorization status.
    event AuthorisationForAllChanged(
        address indexed owner,
        address indexed target,
        bool isAuthorised
    );

    /// @notice Emitted when records associated with a name are cleared
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) whose records were cleared
    /// @param dataVersion The updated version of data after clearing the records
    event RecordsCleared(bytes32 indexed nameHash, uint256 indexed dataVersion);

    /// @notice Emitted when data associated with a name is changed.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @param dataKey The key corresponding to the data that was changed.
    /// @param dataValue The new value of the data.
    event DataChanged(
        bytes32 indexed nameHash,
        bytes32 indexed dataKey,
        bytes dataValue
    );

    /// @notice Sets authorisation for a specific target and name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) for which to set authorisation.
    /// @param target The address to which the authorization is granted or revoked.
    /// @param isAuthorised_ The authorization status to set.
    function setAuthorisation(
        bytes32 nameHash,
        address target,
        bool isAuthorised_
    ) external;

    /// @notice Sets global authorisation for a target.
    /// @param target The address to which the global authorization is granted or revoked.
    /// @param isAuthorised_ The global authorization status to set.
    function setAuthorisationForAll(
        address target,
        bool isAuthorised_
    ) external;

    /// @notice Executes a batch of calls.
    /// @param data An array of call data to be executed.
    /// @return results An array of return data from each executed call.
    function batchCalls(
        bytes[] calldata data
    ) external returns (bytes[] memory results);

    /// @notice Clears all records associated with a name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) for which to clear records.
    function clearRecords(bytes32 nameHash) external;

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
