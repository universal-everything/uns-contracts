// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

import {IUNSRegistry} from "../UNSRegistry/IUNSRegistry.sol";
import {IReverseRegistrar} from "./IReverseRegistrar.sol";

/// @title Reverse Registrar Contract Claimer
/// @notice Contract to be inherited by contracts that wish to claim a reverse record.
/// This contract is designed for interaction with a Universal Naming Service (UNS) Registry
/// to claim reverse records for contract addresses.
/// Example contract to claim a name for a contract, similar contracts can be done
/// that sets the resolver, and other data keys.
contract ReverseRegistrarContractClaimer {
    /// @dev Constant node used for the reverse registrar in the UNS.
    bytes32 constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    /// @notice Creates a new ReverseRegistrarContractClaimer and claims a reverse record.
    /// @param unsRegistry The address of the UNS Registry.
    /// @param claimant The address claiming the reverse record.
    /// The constructor automatically claims a reverse record for the `claimant` address
    /// using the reverse registrar obtained from the UNS registry.
    constructor(IUNSRegistry unsRegistry, address claimant) {
        IReverseRegistrar reverseRegistrar = IReverseRegistrar(
            unsRegistry.owner(ADDR_REVERSE_NODE)
        );
        reverseRegistrar.claim(claimant);
    }
}
