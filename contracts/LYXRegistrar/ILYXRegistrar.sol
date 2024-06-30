// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @title LYXRegistrar interface
/// @notice This is an interface for the registrar managing the LYX names. It includes
/// the ability to add or remove controllers, register and renew names, and
/// manage name ownership. The registered names will be LSP8 assets that can be
/// transferred and traded.
interface ILYXRegistrar {
    /// @notice Emitted when a new controller is added.
    /// @param controller The address of the newly added controller.
    event ControllerAdded(address indexed controller);

    /// @notice Emitted when a controller is removed.
    /// @param controller The address of the removed controller.
    event ControllerRemoved(address indexed controller);

    /// @notice Emitted when a name is registered.
    /// @param id The label hash of the registered name.
    /// @param owner The address of the name owner.
    /// @param expires The expiration timestamp of the name.
    event NameRegistered(
        bytes32 indexed id,
        address indexed owner,
        uint256 expires
    );

    /// @notice Emitted when a name is renewed.
    /// @param id The label hash of the renewed name.
    /// @param expires The expiration timestamp of the name.
    event NameRenewed(bytes32 indexed id, uint256 expires);

    /// @notice Emitted when a name is burned.
    /// @param nameLabelHash The label hash of the burned name.
    event NameBurned(bytes32 indexed nameLabelHash);

    /// @notice Emitted when the maximum gas for burning is changed.
    /// @dev This event logs the new maximum gas value set by the `setMaxBurnGas` function.
    /// @param newMaxBurnGas The new maximum gas value for burning.
    event MaxBurnGasChanged(uint256 newMaxBurnGas);

    /// @dev Emitted when the NFT descriptor is changed.
    /// @param oldDescriptor The address of the previous NFT descriptor.
    /// @param newDescriptor The address of the new NFT descriptor.
    event NFTDescriptorChanged(
        address indexed oldDescriptor,
        address indexed newDescriptor
    );

    /// @dev Emitted when the NFT descriptor setter is changed.
    /// @param oldSetter The address of the previous NFT descriptor setter.
    /// @param newSetter The address of the new NFT descriptor setter.
    event NFTDescriptorSetterChanged(
        address indexed oldSetter,
        address indexed newSetter
    );

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

    /// @notice Sets the resolver for the TLD this registrar manages.
    /// @dev Sets the address of the resolver contract.
    /// @param resolver The address of the resolver.
    function setLYXRegistrarResolver(address resolver) external;

    /// @notice Returns the expiration timestamp of the specified label hash.
    /// @dev Retrieves the expiration timestamp for the given name.
    /// @param id The label hash of the name.
    /// @return The expiration timestamp of the name.
    function nameExpires(bytes32 id) external view returns (uint256);

    /// @notice Returns true if the specified name is available for registration.
    /// @dev Checks if the given name is available for registration.
    /// @param id The label hash of the name.
    /// @return A boolean indicating if the name is available.
    function available(bytes32 id) external view returns (bool);

    /// @notice Registers a name.
    /// @dev Registers a name with the given label hash, owner, and duration.
    /// @param id The label hash of the name to register.
    /// @param owner The address of the name owner.
    /// @param duration The desired registration duration in seconds.
    /// @return The new expiration timestamp of the registered name.
    function register(
        bytes32 id,
        address owner,
        bytes memory ownerData,
        address resolver,
        bytes[] calldata resolverData,
        uint256 duration
    ) external returns (uint256);

    /// @notice Renews a name for a specified duration.
    /// @dev Renews the registration of a name for the given duration.
    /// @param id The label hash of the name to renew.
    /// @param duration The desired renewal duration in seconds.
    /// @return The new expiration timestamp of the renewed name.
    function renew(bytes32 id, uint256 duration) external returns (uint256);
}
