// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

/// @title IRootRegistrar
/// @notice Interface for RootRegistrar contract managing the root of a domain name system.
interface IRootRegistrar {
    /// @notice Emitted when a new controller is added.
    /// @param controller The address of the newly added controller.
    event ControllerAdded(address indexed controller);

    /// @notice Emitted when a controller is removed.
    /// @param controller The address of the removed controller.
    event ControllerRemoved(address indexed controller);

    /// @notice Emitted when a Top-Level Domain (TLD) is locked.
    /// @param label The label of the TLD that is locked.
    event TLDLocked(bytes32 indexed label);

    /// @notice Getter for the UNS_REGISTRY address.
    /// @return The address of the UNS_REGISTRY contract.
    function UNSRegistry() external returns (address);

    /// @return The list of controllers
    function getControllers() external view returns (address[] memory);

    /// @param _addr The address to check
    /// @return True if the address is a controller
    function isController(address _addr) external view returns (bool);

    /// @notice Authorizes a controller, who can register and renew domains.
    /// @dev Adds a controller to the list of authorized controllers.
    /// @param controller The address of the controller to be added.
    function addController(address controller) external;

    /// @notice Revokes controller permission for an address.
    /// @dev Removes a controller from the list of authorized controllers.
    /// @param controller The address of the controller to be removed.
    function removeController(address controller) external;

    /// @notice Checks if a given TLD is locked.
    /// @param labelHash The label hash of the TLD.
    /// @return True if the TLD is locked, false otherwise.
    function isLocked(bytes32 labelHash) external returns (bool);

    /// @notice Locks a TLD, preventing changes to its subdomains.
    /// @param labelHash The label hash of the TLD to be locked.
    function lock(bytes32 labelHash) external;

    /// @notice Sets the resolver for the root domain.
    /// @param resolver The address of the resolver to set for the root.
    function setResolver(address resolver) external;

    /// @notice Sets the owner of a subdomain under the root.
    /// @param label The label hash of the subdomain.
    /// @param _owner The address of the new owner for the subdomain.
    function setSubNameOwner(bytes32 label, address _owner) external;
}
