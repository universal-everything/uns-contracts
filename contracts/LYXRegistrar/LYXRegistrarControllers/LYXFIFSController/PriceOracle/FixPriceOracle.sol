// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

import {IPriceOracle} from "./IPriceOracle.sol";

/// @title FixPriceOracle
contract FixPriceOracle is IPriceOracle {
    /// @notice Retrieves the price for a given name
    /// @param name The name to query the price for
    /// @param expiry The expiry timestamp of the name
    /// @param duration The duration for which the name is to be registered
    /// @return The price
    function price(
        string calldata name,
        uint256 expiry,
        uint256 duration
    ) public view override returns (IPriceOracle.Price memory) {
        return Price(1 ether, 0);
    }
}
