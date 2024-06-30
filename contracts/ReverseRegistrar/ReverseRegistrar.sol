// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

import {IUNSRegistry} from "../UNSRegistry/IUNSRegistry.sol";
import {IReverseRegistrar} from "./IReverseRegistrar.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../Utils/StringUtils.sol";
import "./ReverseRegistrarErrors.sol";
import {NameResolver} from "../resolvers/profiles/NameResolver.sol";

/// @title Reverse Registrar
/// @notice Manages reverse resolution records in a domain name system.
contract ReverseRegistrar is Ownable, IReverseRegistrar {
    bytes32 constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;
    bytes32 constant lookup =
        0x3031323334353637383961626364656600000000000000000000000000000000;

    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Enumerable set of controller addresses with specific control permissions.
    EnumerableSet.AddressSet private _controllers;

    /// @dev Address of the UNS Registry contract.
    address private immutable _UNS_REGISTRY;

    /// @dev Address of the default resolver for reverse records.
    address private _defaultResolver;

    /// @notice Initializes the contract with a specified UNS registry and default resolver.
    /// @param unsRegistry_ Address of the UNS Registry contract.
    constructor(address unsRegistry_) {
        _UNS_REGISTRY = unsRegistry_;
    }

    /// @notice Checks if the caller is authorized.
    /// @dev Modifier that requires the caller to be the specified address, a controller, or authorized by the address itself.
    /// @param addr Address to check for authorization.
    modifier authorised(address addr) {
        require(
            addr == msg.sender ||
                _controllers.contains(msg.sender) ||
                IUNSRegistry(_UNS_REGISTRY).isApprovedForAll(
                    addr,
                    msg.sender
                ) ||
                ownsContract(addr),
            "ReverseRegistrar: Caller is not a controller or authorised by address or the address itself"
        );
        _;
    }

    /// @notice Ensures that the caller is a controller.
    /// @dev Modifier that throws if the caller is not a controller.
    modifier onlyController() {
        if (!_controllers.contains(msg.sender))
            revert ReverseRegistrar_NotController(msg.sender);
        _;
    }

    // Admin Functions

    /// @notice Returns the address of the UNS Registry.
    /// @dev Public function to get the UNS Registry address.
    /// @return Address of the UNS Registry contract.
    function UNSRegistry() public view returns (address) {
        return _UNS_REGISTRY;
    }

    /// @notice Retrieves the list of controllers.
    /// @dev Returns an array of addresses that are controllers.
    /// @return An array of controller addresses.
    function getControllers() external view returns (address[] memory) {
        return _controllers.values();
    }

    /// @notice Checks if an address is a controller.
    /// @dev Public view function to check controller status.
    /// @param _addr Address to check.
    /// @return True if the address is a controller, false otherwise.
    function isController(address _addr) external view returns (bool) {
        return _controllers.contains(_addr);
    }

    /// @notice Adds a controller.
    /// @dev Function to add a new controller, only callable by the owner.
    /// @param controller Address of the controller to be added.
    function addController(address controller) external onlyOwner {
        _controllers.add(controller);
        emit ControllerAdded(controller);
    }

    /// @notice Removes a controller.
    /// @dev Function to remove a controller, only callable by the owner.
    /// @param controller Address of the controller to be removed.
    function removeController(address controller) external onlyOwner {
        _controllers.remove(controller);
        emit ControllerRemoved(controller);
    }

    /// @notice Sets the default resolver for reverse records.
    /// @dev Function to set a new default resolver, only callable by the owner.
    /// @param resolver Address of the new resolver.
    function setDefaultResolver(address resolver) public override onlyOwner {
        if (resolver == address(0))
            revert ReverseRegistrar_ResolverCannotBeZeroAddress();
        _defaultResolver = resolver;
        emit DefaultResolverChanged(resolver);
    }

    // Claim Functions

    /// @notice Claims a reverse record for the calling account.
    /// @dev Transfers ownership of the reverse record associated with the calling account.
    /// @param owner_ Address to set as the owner of the reverse record.
    /// @return The node hash of the reverse record.
    function claim(address owner_) public override returns (bytes32) {
        return claimForAddr(msg.sender, owner_, _defaultResolver);
    }

    /// @notice Claims a reverse record with a specific resolver.
    /// @dev Transfers ownership of the reverse record associated with the calling account to a specified resolver.
    /// @param owner_ The address to set as the owner of the reverse record.
    /// @param resolver The resolver address to set; 0 to leave unchanged.
    /// @return The node hash of the reverse record.
    function claimWithResolver(
        address owner_,
        address resolver
    ) public override returns (bytes32) {
        return claimForAddr(msg.sender, owner_, resolver);
    }

    /// @notice Claims a reverse record with a specific resolver.
    /// @dev Transfers ownership of the reverse record associated with the calling account to a specified resolver.
    /// @param owner_ The address to set as the owner of the reverse record.
    /// @param resolver The resolver address to set; 0 to leave unchanged.
    /// @return The node hash of the reverse record.
    function claimWithResolverData(
        address owner_,
        address resolver,
        bytes[] calldata _resolverData
    ) public returns (bytes32) {
        return
            claimForAddrWithResolverData(
                msg.sender,
                owner_,
                resolver,
                _resolverData
            );
    }

    /// @notice Claims a reverse record for a specific address.
    /// @dev Transfers ownership of the reverse record associated with the specified address.
    /// @param addr The address whose reverse record is being claimed.
    /// @param owner_ The address to set as the owner of the reverse record.
    /// @param resolver The resolver for the reverse node.
    /// @return The node hash of the reverse record.
    function claimForAddr(
        address addr,
        address owner_,
        address resolver
    ) public override authorised(addr) returns (bytes32) {
        bytes32 labelHash = sha3HexAddress(addr);
        bytes32 reverseNode = keccak256(
            abi.encodePacked(ADDR_REVERSE_NODE, labelHash)
        );
        emit ReverseClaimed(addr, reverseNode);
        IUNSRegistry(_UNS_REGISTRY).setSubNameRecord(
            ADDR_REVERSE_NODE,
            labelHash,
            owner_,
            resolver,
            0
        );
        return reverseNode;
    }

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
        bytes[] memory _resolverData
    ) public override authorised(addr) returns (bytes32) {
        bytes32 labelHash = sha3HexAddress(addr);
        bytes32 reverseNode = keccak256(
            abi.encodePacked(ADDR_REVERSE_NODE, labelHash)
        );
        emit ReverseClaimed(addr, reverseNode);

        if (resolver == address(0)) {
            IUNSRegistry(_UNS_REGISTRY).setSubNameOwner(
                ADDR_REVERSE_NODE,
                labelHash,
                owner_
            );
        } else {
            if (_resolverData.length == 0) {
                IUNSRegistry(_UNS_REGISTRY).setSubNameRecord(
                    ADDR_REVERSE_NODE,
                    labelHash,
                    owner_,
                    resolver,
                    0
                );
            } else {
                IUNSRegistry(_UNS_REGISTRY).setSubNameRecordWithResolverData(
                    ADDR_REVERSE_NODE,
                    labelHash,
                    owner_,
                    resolver,
                    0,
                    _resolverData
                );
            }
        }

        return reverseNode;
    }

    function setName(string memory name) public returns (bytes32) {
        return
            setNameForAddr(
                msg.sender,
                msg.sender,
                address(_defaultResolver),
                name
            );
    }

    function setNameForAddr(
        address addr,
        address _owner,
        address resolver,
        string memory name
    ) public returns (bytes32) {
        bytes[] memory resolverData = new bytes[](1);
        resolverData[0] = abi.encodeWithSignature(
            "setName(bytes32,string)",
            node(addr),
            name
        );

        bytes32 node_ = claimForAddrWithResolverData(
            addr,
            _owner,
            resolver,
            resolverData
        );

        return node_;
    }

    /// @notice Computes the node hash for a given account's reverse records.
    /// @dev Returns the node hash for a specific address.
    /// @param addr The address to compute the node hash for.
    /// @return The node hash.
    function node(address addr) public pure override returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(addr))
            );
    }

    /// @dev Determines if the caller owns a contract addr.
    /// @param addr The address of the contract to check.
    /// @return True if the sender is the owner of the contract, false otherwise.
    function ownsContract(address addr) internal view returns (bool) {
        try Ownable(addr).owner() returns (address owner_) {
            return owner_ == msg.sender;
        } catch {
            return false;
        }
    }

    /// @dev Computes the SHA3 hash of the lower-case hexadecimal representation of an Ethereum address.
    /// @param addr The address to hash.
    /// @return ret The SHA3 hash of the lower-case hexadecimal encoding of the input address.
    function sha3HexAddress(address addr) internal pure returns (bytes32 ret) {
        assembly {
            for {
                let i := 40
            } gt(i, 0) {

            } {
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }

            ret := keccak256(0, 40)
        }
    }
}
