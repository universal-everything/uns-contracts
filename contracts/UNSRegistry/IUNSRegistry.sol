// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @title Interface for the Universal Name System (UNS) Registry.
/// @notice This contract provides a way for users to register and manage names.
interface IUNSRegistry {
    /// @notice Emitted when the owner of a name is changed.
    /// @param nameHash The nameHash that was updated.
    /// @param newOwner The new owner of the name.
    event OwnerChanged(bytes32 indexed nameHash, address indexed newOwner);

    /// @notice Emitted when the resolver for a name is changed.
    /// @param nameHash The nameHash that was updated.
    /// @param newResolver The new resolver of the name.
    event ResolverChanged(
        bytes32 indexed nameHash,
        address indexed newResolver
    );

    /// @notice Emitted when the TTL of a name is changed.
    /// @param nameHash The nameHash that was updated.
    /// @param newTTL The updated Time to Live (TTL) value.
    event TTLChanged(bytes32 indexed nameHash, uint64 newTTL);

    /// @notice Emitted when the owner of a name approves or revokes a new operator
    /// @param owner The address of the owner granting or revoking permission
    /// @param operator The address of the operator being approved or revoked
    /// @param approved Boolean status of the approval (true if approved, false if revoked)
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    /// @dev This struct represents a name record, containing information about the owner, resolver, TTL (Time to Live) for a given name.
    struct Record {
        address owner;
        address resolver;
        uint64 ttl;
    }

    //
    // --------- Authorisation Functions ----------
    //

    /// @notice Sets or unsets the approval of a given operator
    /// @dev Grants or revokes permission to an operator to manage all assets of the msg.sender.
    ///      Emits an `ApprovalForAll` event.
    /// @param operator The address to assign the approval to
    /// @param approved True to approve the operator, false to revoke approval
    function setApprovalForAll(address operator, bool approved) external;

    /// @notice Checks if an address is an approved operator for another address
    /// @dev Returns true if the `operator` is approved to manage the names of `owner`.
    /// @param owner The address owning the assets
    /// @param operator The address of the operator to check
    /// @return True if the `operator` is approved for the `owner`, false otherwise
    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);

    //
    // --------- Name Getter Functions ----------
    //

    /// @notice Executes a batch of calls.
    /// @param calls An array of call data to be executed.
    /// @return results An array of return data from each executed call.
    function batchCalls(bytes[] memory calls) external returns (bytes[] memory);

    /// @notice Returns the full record information for a given name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @return The record structure with all record details.
    function record(bytes32 nameHash) external view returns (Record memory);

    /// @notice Checks if a record exists for the specified nameHash.
    /// @dev Determines the existence of a record by checking if the owner's address is not zero.
    /// @param nameHash The specified nameHash.
    /// @return True if a record exists, false otherwise.
    function recordExists(bytes32 nameHash) external view returns (bool);

    /// @notice Returns the address that owns the specified name.
    /// @dev Retrieves the owner's address from the record of the given name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @return The address of the owner.
    function owner(bytes32 nameHash) external view returns (address);

    /// @notice Returns the address of the resolver for the specified name.
    /// @dev Retrieves the resolver's address from the record of the given name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @return The address of the resolver.
    function resolver(bytes32 nameHash) external view returns (address);

    /// @notice Returns the Time to Live (TTL) for the specified name.
    /// @dev Retrieves the TTL from the record of the given name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @return The TTL of the name.
    function ttl(bytes32 nameHash) external view returns (uint64);

    /// @notice Returns the address of the resolver with the data specified for a name.
    /// @dev Retrieves the resolver's address and the data attached to it from the record of the given name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @param resolverDataKeys An array of data keys to be retreived from the resolver for the name.
    /// @return The resolverDataValues.
    function resolverData(
        bytes32 nameHash,
        bytes32[] memory resolverDataKeys
    ) external view returns (bytes[] memory);

    //
    // --------- Name Setter Functions ----------
    //

    /// @notice Sets a complete record for a name.
    /// @dev Sets a new record for name in the registry with provided details.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @param _owner The address of the new owner.
    /// @param _resolver The address of the resolver.
    /// @param _ttl The time to live (TTL) for the name.
    function setRecord(
        bytes32 nameHash,
        address _owner,
        address _resolver,
        uint64 _ttl
    ) external;

    /// @notice Sets a complete record for a name and sets resolver data.
    /// @dev Sets a new record for name in the registry with provided details.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @param _owner The address of the new owner.
    /// @param _resolver The address of the resolver.
    /// @param _ttl The time to live (TTL) for the name.
    /// @param resolverDataKeys An array of data keys to set for the name in the resolver.
    /// @param resolverDataValues An array of values corresponding to the data keys for the name.
    function setRecordWithResolverData(
        bytes32 nameHash,
        address _owner,
        address _resolver,
        uint64 _ttl,
        bytes32[] memory resolverDataKeys,
        bytes[] memory resolverDataValues
    ) external;

    /// @notice Updates the owner address for the specified name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update ownership of.
    /// @param newOwner The address to be set as the new owner.
    function setOwner(bytes32 nameHash, address newOwner) external;

    /// @notice Updates the resolver address for the specified name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update the resolver of.
    /// @param newResolver The address to be set as the new resolver.
    function setResolver(bytes32 nameHash, address newResolver) external;

    /// @notice Updates the TTL for the specified name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update the TTL of.
    /// @param newTTL The new TTL value to be set.
    function setTTL(bytes32 nameHash, uint64 newTTL) external;

    /// @notice Updates the resolver address for the specified name and sets resolver data.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update the resolver of and resolver data.
    /// @param resolverDataKeys An array of data keys to set for the name in the resolver.
    /// @param resolverDataValues An array of values corresponding to the data keys for the name.
    function setResolverData(
        bytes32 nameHash,
        bytes32[] memory resolverDataKeys,
        bytes[] memory resolverDataValues
    ) external;

    //
    // --------- Sub Name Setter Functions ----------
    //

    /// @notice Sets a complete subname record for a name.
    /// @dev Sets a new subname record under parentName with subname details.
    /// @param parentNameHash The nameHash of the parent name (according to the NameHash algorithm) to set a subname for.
    /// @param subNameLabelHash The label hash for the subname.
    /// @param _owner The address of the new owner for the subname.
    /// @param _resolver The address of the resolver for the subname.
    /// @param _ttl The time to live (TTL) for the subname.
    function setSubNameRecord(
        bytes32 parentNameHash,
        bytes32 subNameLabelHash,
        address _owner,
        address _resolver,
        uint64 _ttl
    ) external;

    /// @notice Sets a complete subname record for a name with additional resolver data.
    /// @dev Sets a new subname record under parentName with subname details and additional resolver data.
    /// @param parentNameHash The nameHash of the parent name (according to the NameHash algorithm) to set a subname for.
    /// @param subNameLabelHash The label hash for the subname.
    /// @param _owner The address of the new owner for the subname.
    /// @param _resolver The address of the resolver for the subname.
    /// @param _ttl The time to live (TTL) for the subname.
    /// @param resolverDataKeys An array of data keys to set for the subname in the resolver.
    /// @param resolverDataValues An array of values corresponding to the data keys for the subname.
    function setSubNameRecordWithResolverData(
        bytes32 parentNameHash,
        bytes32 subNameLabelHash,
        address _owner,
        address _resolver,
        uint64 _ttl,
        bytes32[] memory resolverDataKeys,
        bytes[] memory resolverDataValues
    ) external;

    /// @notice Sets a new owner for a subname.
    /// @param parentNameHash The nameHash of the parent name (according to the NameHash algorithm) to set a subname for.
    /// @param subNameLabelHash The label hash for the subname.
    /// @param newOwner The address to be set as the new owner of the subname.
    function setSubNameOwner(
        bytes32 parentNameHash,
        bytes32 subNameLabelHash,
        address newOwner
    ) external;

    /// @notice Sets a new resolver for a subname.
    /// @param parentNameHash The nameHash of the parent name (according to the NameHash algorithm) to set a subname for.
    /// @param subNameLabelHash The label hash for the subname.
    /// @param newResolver The address to be set as the new resolver for the subname.
    function setSubNameResolver(
        bytes32 parentNameHash,
        bytes32 subNameLabelHash,
        address newResolver
    ) external;

    /// @notice Sets a new Time to Live (TTL) for a subname.
    /// @param parentNameHash The nameHash of the parent name (according to the NameHash algorithm) to set a subname for.
    /// @param subNameLabelHash The label hash for the subname.
    /// @param newTTL The new TTL value for the subname.
    function setSubNameTTL(
        bytes32 parentNameHash,
        bytes32 subNameLabelHash,
        uint64 newTTL
    ) external;

    /// @notice Updates the resolver address for a subname and sets resolver data.
    /// @param parentNameHash The nameHash of the parent name (according to the NameHash algorithm) to set a subname for.
    /// @param subNameLabelHash The label hash for the subname.
    /// @param resolverDataKeys An array of data keys to set for the subname in the resolver.
    /// @param resolverDataValues An array of values corresponding to the data keys for the subname.
    function setSubNameResolverData(
        bytes32 parentNameHash,
        bytes32 subNameLabelHash,
        bytes32[] memory resolverDataKeys,
        bytes[] memory resolverDataValues
    ) external;
}
