// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

/// @title IPriceOracle
/// @notice Interface for a price oracle contract
interface IPriceOracle {
    struct Price {
        uint256 base;
        uint256 premium;
    }

    /// @notice Retrieves the price for a given name
    /// @param name The name to query the price for
    /// @param expiry The expiry timestamp of the name
    /// @param duration The duration for which the name is to be registered
    /// @return The price
    function price(
        string calldata name,
        uint256 expiry,
        uint256 duration
    ) external view returns (Price calldata);
}
