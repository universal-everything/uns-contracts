//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "../LYXRegistrar/LYXRegistrarControllers/LYXFIFSController/LYXFIFSController.sol";
import "../LYXRegistrar/LYXRegistrarControllers/LYXFIFSController/PriceOracle/IPriceOracle.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title StaticBulkRenewal
/// @dev A contract for calculating the total rent price for renewing multiple domain names at once using LYXFIFSController.
contract StaticBulkRenewal {
    LYXFIFSController public controller;

    /// @notice Initializes the contract with the given controller.
    /// @param _controller The address of the LYXFIFSController contract.
    constructor(LYXFIFSController _controller) {
        controller = _controller;
    }

    /// @notice Calculates the total rent price for renewing multiple names for a given duration.
    /// @param names An array of names to be renewed.
    /// @param duration The duration in seconds for which each name should be renewed.
    /// @return total The total rent price for renewing the given names for the specified duration.
    function rentPrice(
        string[] calldata names,
        uint256 duration
    ) external view returns (uint256 total) {
        uint256 length = names.length;
        for (uint256 i = 0; i < length; ) {
            IPriceOracle.Price memory price = controller.rentPrice(
                names[i],
                duration
            );
            unchecked {
                ++i;
                total += (price.base + price.premium);
            }
        }
    }
}
