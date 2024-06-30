// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

import {IPriceOracle} from "./PriceOracle/IPriceOracle.sol";

/// @title Interface for ETHRegistrarController
/// @notice Provides an interface for external and public interactions with ETHRegistrarController
interface ILYXFIFSController {
    /// @notice Emitted when a name is registered
    /// @param name The ENS name registered
    /// @param label The label hash of the name
    /// @param owner The owner of the name after registration
    /// @param cost The cost in wei for registering the name
    /// @param expires The expiration time of the registration
    event NameRegistered(
        string name,
        bytes32 indexed label,
        address indexed owner,
        uint256 cost,
        uint256 expires
    );

    /// @notice Emitted when a new price oracle is set
    /// @param oracle The address of the new price oracle
    event NewPriceOracle(address indexed oracle);

    /// @notice Returns the rental price for a name based on the duration
    /// @param name The ENS name to query
    /// @param duration The registration or renewal duration in seconds
    /// @return price The price in wei
    function rentPrice(
        string memory name,
        uint256 duration
    ) external view returns (IPriceOracle.Price memory);

    /// @notice Checks if a name meets the minimum length requirements
    /// @param name The ENS name to validate
    /// @return isValid True if the name is valid (meets minimum length)
    function valid(string memory name) external pure returns (bool);

    /// @notice Checks if a name is available for registration
    /// @param name The ENS name to check for availability
    /// @return isAvailable True if the name is available
    function available(string memory name) external view returns (bool);

    /// @notice Generates a commitment hash to register a name using a basic commit-reveal scheme
    /// @param name The ENS name to commit
    /// @param owner The address intended to own the name
    /// @param secret A secret phrase to protect the commitment
    /// @return commitment The commitment hash
    function makeCommitment(
        string memory name,
        address owner,
        uint256 duration,
        bytes32 secret
    ) external pure returns (bytes32);

    /// @notice Generates a commitment hash for registering a name with additional configuration options
    /// @param name The ENS name to commit
    /// @param owner The address intended to own the name
    /// @param secret A secret phrase to protect the commitment
    /// @param resolver The resolver address for the name
    /// @param addr The address to which the name will point
    /// @param reverseRecord True if a reverse record should be set
    /// @return commitment The commitment hash
    function makeCommitmentWithConfig(
        string memory name,
        address owner,
        uint256 duration,
        bytes32 secret,
        address resolver,
        address addr,
        bool reverseRecord
    ) external pure returns (bytes32);

    /// @notice Records a commitment in the contract
    /// @param commitment The commitment hash to store
    function commit(bytes32 commitment) external;

    /// @notice Registers a name using a prior commitment with a basic configuration
    /// @param name The ENS name to register
    /// @param owner The future owner of the name
    /// @param duration The registration period in seconds
    /// @param secret The secret used in the commitment
    function register(
        string calldata name,
        address owner,
        uint256 duration,
        bytes32 secret
    ) external payable;

    /// @notice Registers a name with configuration options using a prior commitment
    /// @param name The ENS name to register
    /// @param owner The future owner of the name
    /// @param duration The registration period in seconds
    /// @param secret The secret used in the commitment
    /// @param resolver The resolver to use for the name
    /// @param addr The address to associate with the name
    /// @param reverseRecord True if a reverse record should be set
    function registerWithConfig(
        string memory name,
        address owner,
        uint256 duration,
        bytes32 secret,
        address resolver,
        address addr,
        bool reverseRecord
    ) external payable;

    /// @notice Sets a new price oracle for calculating name registration and renewal prices
    /// @param _prices The new PriceOracle contract address
    function setPriceOracle(IPriceOracle _prices) external;

    /// @notice Adjusts the allowable age window for commitments
    /// @param _minCommitmentAge The minimum age in seconds
    /// @param _maxCommitmentAge The maximum age in seconds
    function setCommitmentAges(
        uint256 _minCommitmentAge,
        uint256 _maxCommitmentAge
    ) external;

    /// @notice Allows the owner to withdraw all funds collected by the contract
    function withdraw() external;
}
