// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

/// @title Interface for Reverse Registrar
/// @dev Interface for managing reverse resolution
interface IReverseRegistrar {
    event ReverseClaimed(address indexed addr, bytes32 indexed node);
    event DefaultResolverChanged(address indexed resolver);

    /// @notice Emitted when a new controller is added.
    /// @param controller The address of the newly added controller.
    event ControllerAdded(address indexed controller);

    /// @notice Emitted when a controller is removed.
    /// @param controller The address of the removed controller.
    event ControllerRemoved(address indexed controller);

    /// @notice Sets the default resolver for reverse records
    /// @param resolver The address of the resolver contract
    function setDefaultResolver(address resolver) external;

    /// @notice Claims a reverse record for the sender
    /// @return The node hash of the reverse record
    function claim(address owner) external returns (bytes32);

    /// @notice Claims a reverse record for a specified address
    /// @param addr The address for which to claim a reverse record
    /// @param owner The owner of the reverse record
    /// @param resolver The resolver for the reverse record
    /// @return The node hash of the reverse record
    function claimForAddr(
        address addr,
        address owner,
        address resolver
    ) external returns (bytes32);

    /// @notice Claims a reverse record with a specified resolver
    /// @param owner The owner of the reverse record
    /// @param resolver The resolver for the reverse record
    /// @return The node hash of the reverse record
    function claimWithResolver(
        address owner,
        address resolver
    ) external returns (bytes32);

    /// @notice Claims a reverse record for a specific address.
    /// @dev Transfers ownership of the reverse record associated with the specified address.
    /// @param addr The address whose reverse record is being claimed.
    /// @param owner_ The address to set as the owner of the reverse record.
    /// @param resolver The resolver for the reverse node.
    /// @return The node hash of the reverse record.
    function claimForAddrWithResolverData(
        address addr,
        address owner_,
        address resolver,
        bytes32[] memory resolverDataKeys,
        bytes[] memory resolverDataValues
    ) external returns (bytes32);
    /// @notice Computes the node hash for a given address
    /// @dev This is a pure function; it does not read from or modify the state
    /// @param addr The address for which to compute the node hash
    /// @return The node hash for the given address
    function node(address addr) external pure returns (bytes32);
}
