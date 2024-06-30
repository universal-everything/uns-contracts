// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

import "../UNSRegistry/IUNSRegistry.sol";
import "./IDefaultResolver.sol";
import "./DefaultResolverErrors.sol";

/// @title Default Resolver
/// @notice A simple resolver allowing the owner of a name to set its address and manage data.
contract DefaultResolver is IDefaultResolver {
    /// @notice The UNS Registry contract address.
    IUNSRegistry public immutable UNS_Registry;

    /// @dev Stores the version of data for a name.
    mapping(bytes32 => uint256) private _dataVersion;

    /// @dev Stores the data for a name, keyed by version and data key.
    mapping(bytes32 => mapping(uint256 => mapping(bytes32 => bytes)))
        private _dataStore;

    /// @notice Authorisations mapping, allowing specified addresses to manage name data.
    mapping(address => mapping(bytes32 => mapping(address => bool)))
        public authorisations;

    /// @notice Global authorisations mapping, allowing specified addresses to manage any name data.
    mapping(address => mapping(address => bool)) public authorisationsForAll;

    /// @dev Modifier to restrict function access to authorised addresses.
    modifier authorised(bytes32 nameHash) {
        if (!isAuthorised(nameHash))
            revert DefaultResolver_NotAuthorized(nameHash, msg.sender);
        _;
    }

    /// @notice Constructor sets the UNS Registry contract.
    /// @param _uns The address of the UNS Registry contract.
    constructor(IUNSRegistry _uns) {
        UNS_Registry = _uns;
    }

    /// @notice Sets or clears an authorisation for a specific name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) for which to set authorisation.
    /// @param target The address to be authorised or deauthorised.
    /// @param isAuthorised_ The authorisation status to set.
    function setAuthorisation(
        bytes32 nameHash,
        address target,
        bool isAuthorised_
    ) external {
        authorisations[msg.sender][nameHash][target] = isAuthorised_;
        emit AuthorisationChanged(msg.sender, nameHash, target, isAuthorised_);
    }

    /// @notice Sets or clears a global authorisation.
    /// @param target The address to be authorised or deauthorised globally.
    /// @param isAuthorised_ The global authorisation status to set.
    function setAuthorisationForAll(
        address target,
        bool isAuthorised_
    ) external {
        authorisationsForAll[msg.sender][target] = isAuthorised_;
        emit AuthorisationForAllChanged(msg.sender, target, isAuthorised_);
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
                    revert DefaultResolver_BatchCallFailed(i);
                }
            }

            results[i] = result;
        }
    }

    /// @notice Clears all records associated with a name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to clear records.
    function clearRecords(bytes32 nameHash) external authorised(nameHash) {
        _dataVersion[nameHash]++;
        emit RecordsCleared(nameHash, _dataVersion[nameHash]);
    }

    /// @notice Retrieves data associated with a name and key.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) from which to retrieve data.
    /// @param dataKey The key corresponding to the data to retrieve.
    /// @return The data value associated with the given name and key.
    function getData(
        bytes32 nameHash,
        bytes32 dataKey
    ) external view returns (bytes memory) {
        uint256 recordsVersion = _dataVersion[nameHash];
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
        uint256 recordsVersion = _dataVersion[nameHash];

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
        uint256 recordsVersion = _dataVersion[nameHash];
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
            revert DefaultResolver_DataLengthMismatch();
        }

        if (dataKeys.length == 0) {
            revert DefaultResolver_DataEmptyArray();
        }

        uint256 recordsVersion = _dataVersion[nameHash];
        for (uint256 i = 0; i < dataKeys.length; ) {
            _setData(nameHash, recordsVersion, dataKeys[i], dataValues[i]);

            // Increment the iterator in unchecked block to save gas
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Checks if an address is authorised to manage the given name.
    /// @param nameHash The nameHash of the name (according to the NameHash algorithm) to check authorisation for.
    /// @return True if the caller is authorised, false otherwise.
    function isAuthorised(bytes32 nameHash) internal view returns (bool) {
        if (msg.sender == address(UNS_Registry)) return true;
        address owner = UNS_Registry.owner(nameHash);
        return
            owner == msg.sender ||
            authorisations[owner][nameHash][msg.sender] ||
            authorisationsForAll[owner][msg.sender];
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
