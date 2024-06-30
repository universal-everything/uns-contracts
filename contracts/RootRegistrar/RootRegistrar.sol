// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

// Importing ERC165 and Ownable from OpenZeppelin
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../UNSRegistry/IUNSRegistry.sol";
import "./IRootRegistrar.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./RootRegistrarErrors.sol";

/// @title RootRegistrar
/// @dev This contract manages the root of UNS and allows setting controllers.
/// Only setResolver is put here, as you don't want this contract owning the root name to be able to swap to a new contract that
/// can change subnames that has been locked. Same apply for ttl function.
contract RootRegistrar is ERC165, Ownable, IRootRegistrar {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Constant hash for the root name.
    bytes32 private constant ROOT_NAME_HASH = bytes32(0);

    /// @dev Address of the UNS Registry.
    address private immutable _UNS_REGISTRY;

    /// @dev Enumerable set of controller addresses.
    /// @notice This set stores addresses that have specific control permissions in the contract.
    EnumerableSet.AddressSet private _controllers;

    /// @dev Mapping to track locked state of domain name hashes.
    /// @notice Tracks whether a particular domain name hash is locked.
    mapping(bytes32 => bool) private _locked;

    /// @notice Initializes the contract with a UNSRegistry and an owner
    /// @param uns_Registry The UNSRegistry contract
    /// @param _owner The owner of the contract
    constructor(address uns_Registry, address _owner) {
        _UNS_REGISTRY = uns_Registry;
        _controllers.add(_owner);
        _transferOwnership(_owner);
    }

    /// @notice Ensures that the caller is a controller
    /// @dev Throws if the caller is not a controller
    modifier onlyController() {
        if (!_controllers.contains(msg.sender))
            revert RootRegistrar_NotController(msg.sender);
        _;
    }

    function UNSRegistry() public virtual returns (address) {
        return address(_UNS_REGISTRY);
    }

    /// @return The list of controllers
    function getControllers() external view returns (address[] memory) {
        return _controllers.values();
    }

    /// @param _addr The address to check
    /// @return True if the address is a controller
    function isController(address _addr) external view returns (bool) {
        return _controllers.contains(_addr);
    }

    /// @notice Authorizes a controller, who can register and renew domains.
    /// @dev Adds a controller to the list of authorized controllers.
    /// @param controller The address of the controller to be added.
    function addController(address controller) external onlyOwner {
        _controllers.add(controller);
        emit ControllerAdded(controller);
    }

    /// @notice Revokes controller permission for an address.
    /// @dev Removes a controller from the list of authorized controllers.
    /// @param controller The address of the controller to be removed.
    function removeController(address controller) external onlyOwner {
        _controllers.remove(controller);
        emit ControllerRemoved(controller);
    }

    /// @notice Checks if a given TLD is locked.
    /// @param labelHash The label hash of the TLD.
    /// @return True if the TLD is locked, false otherwise.
    function isLocked(bytes32 labelHash) external view returns (bool) {
        return _locked[labelHash];
    }

    /// @notice Locks a TLD
    /// @param labelHash The label hash of the TLD
    function lock(bytes32 labelHash) external onlyOwner {
        emit TLDLocked(labelHash);
        _locked[labelHash] = true;
    }

    /// @notice Sets the resolver for the root
    /// @param resolver The resolver's address
    function setResolver(address resolver) external onlyOwner {
        IUNSRegistry(_UNS_REGISTRY).setResolver(ROOT_NAME_HASH, resolver);
    }

    /// @notice Sets the owner of a subname
    /// @param labelHash The label hash of the subname
    /// @param _owner The new owner's address
    function setSubNameOwner(
        bytes32 labelHash,
        address _owner
    ) external onlyController {
        if (_locked[labelHash]) revert RootRegistrar_NameIsLocked(labelHash);
        IUNSRegistry(_UNS_REGISTRY).setSubNameOwner(
            ROOT_NAME_HASH,
            labelHash,
            _owner
        );
    }

    /// @notice Checks if the contract supports a specific interface
    /// @param interfaceID The interface identifier
    /// @return True if the interface is supported
    function supportsInterface(
        bytes4 interfaceID
    ) public pure override returns (bool) {
        return
            interfaceID == type(ERC165).interfaceId ||
            interfaceID == type(Ownable).interfaceId;
    }
}
