// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// interfaces
import {IUNSRegistry} from "./IUNSRegistry.sol";

// libraries
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// errors
import "./UNSRegistryErrors.sol";

/// @title Implementation of the Universal Name System (UNS) Registry.
/// @notice This contract provides a way for users to register and manage names.
contract UNSRegistry is IUNSRegistry {
    /// @notice Mapping of nameHash of a name to their respective records.
    mapping(bytes32 => Record) internal _records;

    /// @notice Mapping of addresses to their operators and the operator status.
    mapping(address => mapping(address => bool)) private _operators;

    /// @dev Permits modifications only by the owner of the specified name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    modifier authorised(bytes32 nameHash) {
        address _owner = _records[nameHash].owner;
        bool isOperatorOrOwner = _owner == msg.sender ||
            _operators[_owner][msg.sender];

        if (!isOperatorOrOwner) {
            revert UNSRegistry_NotAuthorized(nameHash, _owner, msg.sender);
        }
        _;
    }

    /// @notice Creates a new UNS Registry and sets the root owner to the provided address.
    /// @dev Initializes the root nameHash with predefined values for resolver, ttl.
    /// @param rootOwner The address of the root owner (the contract who will own the root).
    constructor(address rootOwner) {
        _records[bytes32(0)] = Record({
            owner: rootOwner,
            resolver: address(0),
            ttl: 0
        });
    }

    /// @notice Executes a batch of calls.
    /// @param data An array of call data to be executed.
    /// @return results An array of return data from each executed call.
    function batchCalls(
        bytes[] calldata data
    ) public virtual override returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );

            if (!success) {
                // Look for revert reason and bubble it up if present
                if (result.length != 0) {
                    // The easiest way to bubble the revert reason is using memory via assembly
                    // solhint-disable no-inline-assembly
                    /// @solidity memory-safe-assembly
                    assembly {
                        let returndata_size := mload(result)
                        revert(add(32, result), returndata_size)
                    }
                } else {
                    revert UNSRegistry_BatchCallFailed(i);
                }
            }

            results[i] = result;
        }
    }

    //
    // --------- Access Functions ----------
    //

    /// @notice Sets or unsets the approval of a given operator
    /// @dev Grants or revokes permission to an operator to transfer all of the caller's names.
    /// @param operator The address to approve or disapprove.
    /// @param approved True if the operator is approved, false to revoke approval.
    function setApprovalForAll(
        address operator,
        bool approved
    ) external virtual {
        _operators[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Checks if an operator is approved to manage all assets of an owner.
    /// @dev Returns true if the operator is approved by the owner.
    /// @param _owner The address of the assets' owner.
    /// @param operator The address of the operator to check.
    /// @return True if the operator is approved, false otherwise.
    function isApprovedForAll(
        address _owner,
        address operator
    ) external view virtual returns (bool) {
        return _operators[_owner][operator];
    }

    //
    // --------- Name Getter Functions ----------
    //

    /// @notice Returns the full record information for a given name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @return The record structure with all record details.
    function record(bytes32 nameHash) external view returns (Record memory) {
        return _records[nameHash];
    }

    /// @notice Checks if a record exists for the specified nameHash.
    /// @dev Determines the existence of a record by checking if the owner's address is not zero.
    /// @param nameHash The specified nameHash.
    /// @return True if a record exists, false otherwise.
    function recordExists(bytes32 nameHash) external view returns (bool) {
        return _records[nameHash].owner != address(0);
    }

    /// @notice Returns the address that owns the specified name.
    /// @dev Retrieves the owner's address from the record of the given name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @return The address of the owner.
    function owner(bytes32 nameHash) external view returns (address) {
        return _records[nameHash].owner;
    }

    /// @notice Returns the address of the resolver for the specified name.
    /// @dev Retrieves the resolver's address from the record of the given name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @return The address of the resolver.
    function resolver(bytes32 nameHash) external view returns (address) {
        return _records[nameHash].resolver;
    }

    /// @notice Returns the Time to Live (TTL) for the specified name.
    /// @dev Retrieves the TTL from the record of the given name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @return The TTL of the name.
    function ttl(bytes32 nameHash) external view returns (uint64) {
        return _records[nameHash].ttl;
    }

    /// @notice Returns the resolver's data specified for a name.
    /// @dev Retrieves the resolver's data attached to it from the record of the given name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @param _resolverData The data to be retreived from the resolver for the name.
    /// @return _resolver The address of the resolver
    /// @return results The resolverDataValues.
    function resolverData(
        bytes32 nameHash,
        bytes[] calldata _resolverData
    ) external view returns (address _resolver, bytes[] memory results) {
        _resolver = _records[nameHash].resolver;
        for (uint256 i = 0; i < _resolverData.length; i++) {
            (bool success, bytes memory returnedData) = _resolver.staticcall(
                _resolverData[i]
            );

            Address.verifyCallResult(
                success,
                returnedData,
                "UNSRegistry: Getting resolver data failed"
            );

            results[i] = returnedData;
        }
    }

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
    ) external authorised(nameHash) {
        _setOwner(nameHash, _owner);
        emit OwnerChanged(nameHash, _owner);

        _setResolver(nameHash, _resolver);
        _setTTL(nameHash, _ttl);
    }

    /// @notice Sets a complete record for a name and sets resolver data.
    /// @dev Sets a new record for name in the registry with provided details.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm).
    /// @param _owner The address of the new owner.
    /// @param _resolver The address of the resolver.
    /// @param _ttl The time to live (TTL) for the name.
    /// @param _resolverData The data to be set in the resolver for a name.
    function setRecordWithResolverData(
        bytes32 nameHash,
        address _owner,
        address _resolver,
        uint64 _ttl,
        bytes[] calldata _resolverData
    ) external authorised(nameHash) {
        _setOwner(nameHash, _owner);
        emit OwnerChanged(nameHash, _owner);

        _setResolver(nameHash, _resolver);
        _setTTL(nameHash, _ttl);

        _setResolverData(nameHash, _resolver, _resolverData);
    }

    /// @notice Updates the owner address for the specified name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update ownership of.
    /// @param newOwner The address to be set as the new owner.
    function setOwner(
        bytes32 nameHash,
        address newOwner
    ) external authorised(nameHash) {
        _setOwner(nameHash, newOwner);
        emit OwnerChanged(nameHash, newOwner);
    }

    /// @notice Updates the resolver address for the specified name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update the resolver of.
    /// @param newResolver The address to be set as the new resolver.
    function setResolver(
        bytes32 nameHash,
        address newResolver
    ) external authorised(nameHash) {
        _setResolver(nameHash, newResolver);
    }

    /// @notice Updates the TTL for the specified name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update the TTL of.
    /// @param newTTL The new TTL value to be set.
    function setTTL(
        bytes32 nameHash,
        uint64 newTTL
    ) external authorised(nameHash) {
        _setTTL(nameHash, newTTL);
    }

    /// @notice Sets resolver data.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update the resolver of and resolver data.
    /// @param _resolverData An array of data keys to set for the name in the resolver.
    function setResolverData(
        bytes32 nameHash,
        bytes[] calldata _resolverData
    ) external authorised(nameHash) {
        address _resolver = _records[nameHash].resolver;
        _setResolverData(nameHash, _resolver, _resolverData);
    }

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
    ) external authorised(parentNameHash) {
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );
        _setOwner(subNameHash, _owner);
        emit SubnNameOwnerChanged(parentNameHash, subNameLabelHash, _owner);

        _setResolver(subNameHash, _resolver);
        _setTTL(subNameHash, _ttl);
    }

    /// @notice Sets a complete subname record for a name with additional resolver data.
    /// @dev Sets a new subname record under parentName with subname details and additional resolver data.
    /// @param parentNameHash The nameHash of the parent name (according to the NameHash algorithm) to set a subname for.
    /// @param subNameLabelHash The label hash for the subname.
    /// @param _owner The address of the new owner for the subname.
    /// @param _resolver The address of the resolver for the subname.
    /// @param _ttl The time to live (TTL) for the subname.
    /// @param _resolverData The data to be set for the subname in the resolver.
    function setSubNameRecordWithResolverData(
        bytes32 parentNameHash,
        bytes32 subNameLabelHash,
        address _owner,
        address _resolver,
        uint64 _ttl,
        bytes[] calldata _resolverData
    ) external authorised(parentNameHash) {
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );
        _setOwner(subNameHash, _owner);
        emit SubnNameOwnerChanged(parentNameHash, subNameLabelHash, _owner);

        _setResolver(subNameHash, _resolver);
        _setTTL(subNameHash, _ttl);

        _setResolverData(subNameHash, _resolver, _resolverData);
    }

    /// @notice Sets a new owner for a subname.
    /// @param parentNameHash The nameHash of the parent name (according to the NameHash algorithm) to set a subname for.
    /// @param subNameLabelHash The label hash for the subname.
    /// @param newOwner The address to be set as the new owner of the subname.
    function setSubNameOwner(
        bytes32 parentNameHash,
        bytes32 subNameLabelHash,
        address newOwner
    ) external authorised(parentNameHash) {
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );
        _setOwner(subNameHash, newOwner);
        emit SubnNameOwnerChanged(parentNameHash, subNameLabelHash, newOwner);
    }

    /// @notice Sets a new resolver for a subname.
    /// @param parentNameHash The nameHash of the parent name (according to the NameHash algorithm) to set a subname for.
    /// @param subNameLabelHash The label hash for the subname.
    /// @param newResolver The address to be set as the new resolver for the subname.
    function setSubNameResolver(
        bytes32 parentNameHash,
        bytes32 subNameLabelHash,
        address newResolver
    ) external authorised(parentNameHash) {
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );
        _setResolver(subNameHash, newResolver);
    }

    /// @notice Sets a new Time to Live (TTL) for a subname.
    /// @param parentNameHash The nameHash of the parent name (according to the NameHash algorithm) to set a subname for.
    /// @param subNameLabelHash The label hash for the subname.
    /// @param newTTL The new TTL value for the subname.
    function setSubNameTTL(
        bytes32 parentNameHash,
        bytes32 subNameLabelHash,
        uint64 newTTL
    ) external authorised(parentNameHash) {
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );
        _setTTL(subNameHash, newTTL);
    }

    /// @notice Sets resolver data.
    /// @param parentNameHash The nameHash of the parent name (according to the NameHash algorithm) to set a subname for.
    /// @param subNameLabelHash The label hash for the subname.
    /// @param _resolverData The data to be set for the subname in the resolver.
    function setSubNameResolverData(
        bytes32 parentNameHash,
        bytes32 subNameLabelHash,
        bytes[] calldata _resolverData
    ) external authorised(parentNameHash) {
        bytes32 subNameHash = keccak256(
            abi.encodePacked(parentNameHash, subNameLabelHash)
        );
        address _resolver = _records[subNameHash].resolver;
        _setResolverData(subNameHash, _resolver, _resolverData);
    }

    /// @dev Sets the owner of the specified name.
    /// Emits a {OwnerChanged} event.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update ownership of.
    /// @param newOwner The address of the new owner.
    function _setOwner(bytes32 nameHash, address newOwner) internal {
        _records[nameHash].owner = newOwner;
    }

    /// @dev Sets the resolver of the specified name.
    /// Emits a {ResolverChanged} event.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update resolver of.
    /// @param newResolver The address of the new resolver.
    function _setResolver(bytes32 nameHash, address newResolver) internal {
        _records[nameHash].resolver = newResolver;
        emit ResolverChanged(nameHash, newResolver);
    }

    /// @dev Sets the TTL for the specified name.
    /// Emits a {TTLChanged} event.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update the TTL of.
    /// @param newTTL The new Time to Live (TTL) value.
    function _setTTL(bytes32 nameHash, uint64 newTTL) internal {
        _records[nameHash].ttl = newTTL;
        emit TTLChanged(nameHash, newTTL);
    }

    /// @dev Sets the resolver data in the resolver address.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to update the TTL of.
    /// @param _resolver The address of the resolver.
    /// @param _resolverData The data to be set in the resolver of the name.
    function _setResolverData(
        bytes32 nameHash,
        address _resolver,
        bytes[] calldata _resolverData
    ) internal {
        for (uint256 i = 0; i < _resolverData.length; i++) {
            if (bytes32(_resolverData[i][4:36]) != nameHash) {
                revert UNSRegistry_ChangingResolverDataDisallowed(
                    nameHash,
                    _resolver,
                    _resolverData[i]
                );
            }

            (bool success, bytes memory returnedData) = _resolver.call(
                _resolverData[i]
            );

            Address.verifyCallResult(
                success,
                returnedData,
                "UNSRegistry: Setting resolver data failed"
            );
        }
    }

    //////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////

    /// @dev Checks if a record is valid according to its registrar.
    function validity(
        bytes32[] memory labels
    ) public view returns (bytes32, bool) {
        bytes32 namehash = 0x0000000000000000000000000000000000000000000000000000000000000000;
        bool valid = true;
        for (uint i = labels.length; i > 0; i--) {
            address registrarAddress = _records[namehash].owner;
            namehash = keccak256(abi.encodePacked(namehash, labels[i - 1]));

            // Check if owner is EOA
            if (registrarAddress.code.length == 0) {
                // If the Owner is an EOA, its automatically valid
                continue;
            }

            (bool success, bytes memory result) = registrarAddress.staticcall(
                abi.encodeWithSignature("isActive(bytes32)", labels[i - 1])
            );

            // If a contract don't implement the isValid function, it's considered valid
            if (!success) {
                continue;
            }

            // Only considered invalid if the isValid function return false
            bool _valid = abi.decode(result, (bool));
            valid = valid && _valid;

            if (!valid) {
                break; // If any label is invalid, exit the loop
            }
        }

        return (namehash, valid);
    }
}
