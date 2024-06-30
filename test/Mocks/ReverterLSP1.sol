// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// MockResolver for testing purposes
contract ReverterLSP1 {
    function supportsInterface(
        bytes4 interfaceID
    ) external pure returns (bool) {
        return interfaceID == 0x6bb56a14;
    }

    function universalReceiver(
        bytes32 typeId,
        bytes memory data
    ) public payable returns (bytes memory) {
        if (
            typeId ==
            0xb23eae7e6d1564b295b4c3e3be402d9a2f0776c57bdf365903496f6fa481ab00
        ) {
            revert("This is a revert message");
        }
    }
}
