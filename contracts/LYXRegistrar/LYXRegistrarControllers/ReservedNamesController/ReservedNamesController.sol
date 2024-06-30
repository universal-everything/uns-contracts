// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../LYXRegistrar.sol";
import "../../LYXRegistrarConstants.sol";
import "../../../ReverseRegistrar/IReverseRegistrar.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP4DigitalAssetMetadata/LSP4Constants.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP1UniversalReceiver/LSP1Constants.sol";

/// @title Reserved Names Controller
/// @notice Manages the reservation of specific names within a registrar system
/// @dev Utilizes the LYXRegistrar contract for name registration
/// No need for a renew function as this controller is intended to run for less
/// than a month, and names are reserved for a minimum duration of one year
contract ReservedNamesController is Ownable {
    /// @dev The address of the LYXRegistrar contract
    LYXRegistrar public immutable LYX_Registrar;

    /// @notice Controller for the LYX registrar
    /// @param _LYX_Registrar The address of the LYXRegistrar contract
    /// @param newOwner The address to which the ownership of the contract is transferred after setup
    constructor(LYXRegistrar _LYX_Registrar, address newOwner) {
        LYX_Registrar = _LYX_Registrar;
        _transferOwnership(newOwner);
    }

    /// @notice Checks if a name is available for reservation (off-chain)
    /// @dev Checks are made off-chain, this function provides on-chain verification
    /// No need to check whether the name is of length >= 3
    /// @param name The name to be checked for availability
    /// @return True if the name is available for reservation, false otherwise
    function available(string memory name) public view returns (bool) {
        bytes32 label = keccak256(bytes(name));
        return LYX_Registrar.available(label);
    }

    /// @notice Reserves a single name
    /// @dev Only owner can reserve names
    /// Name information is not set as the primary purpose is to reserve
    /// names rather than to put them into active use.
    /// @param name The name to be reserved
    /// @param owner_ The address that will own the reserved name
    /// @param duration The duration for which the name is reserved
    function reserve(
        string memory name,
        address owner_,
        uint256 duration
    ) external onlyOwner {
        bytes32 label = keccak256(bytes(name));
        bytes32[] memory resolverDataKeys;
        bytes[] memory resolverDataValues;

        LYX_Registrar.register(
            label,
            owner_,
            "",
            address(0),
            resolverDataKeys,
            resolverDataValues,
            duration
        );

        LYX_Registrar.setDataForTokenId(
            label,
            LYX_REGISTRAR_TOKENID_NAME,
            bytes(name)
        );
    }

    /// @notice Reserves multiple names in a batch
    /// @dev Only the owner can reserve names
    /// Name information is not set as the primary purpose is to reserve
    /// names rather than to put them into active use.
    /// @param names An array of names to be reserved
    /// @param owner_ The address that will own the reserved names
    /// @param duration The duration for which each name is reserved
    function reserve(
        string[] memory names,
        address owner_,
        uint256 duration
    ) external onlyOwner {
        bytes32[] memory resolverDataKeys;
        bytes[] memory resolverDataValues;
        bytes32 label;
        for (uint256 i = 0; i < names.length; i++) {
            label = keccak256(bytes(names[i]));
            LYX_Registrar.register(
                label,
                owner_,
                "",
                address(0),
                resolverDataKeys,
                resolverDataValues,
                duration
            );

            LYX_Registrar.setDataForTokenId(
                label,
                LYX_REGISTRAR_TOKENID_NAME,
                bytes(names[i])
            );
        }
    }

    /// @notice Rejects any incoming tokens to the contract
    /// @dev Function to prevent accidental token transfers to the contract
    /// @return Always reverts with the message "Should not receive tokens"
    function universalReceiver(
        bytes32 /*typeId*/,
        bytes memory /*data*/
    ) external payable returns (bytes memory) {
        revert("Should not receive tokens");
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == _INTERFACEID_LSP1;
    }
}
