// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/LYXRegistrar/LYXRegistrarControllers/ReservedNamesController/ReservedNamesController.sol";
import "../contracts/LYXRegistrar/LYXRegistrar.sol";
import "../contracts/UNSRegistry/UNSRegistry.sol";
import "../contracts/UNSRegistry/IUNSRegistry.sol";

contract ReservedNamesControllerTest is Test {
    ReservedNamesController reservedNamesController;
    LYXRegistrar lyxRegistrar;
    IUNSRegistry unsRegistry;
    bytes32 constant LYX_NAMEHASH =
        keccak256(abi.encodePacked(bytes32(0), keccak256("lyx")));

    function setUp() public {
        // Deploy UNS Registry
        unsRegistry = new UNSRegistry(address(this));

        // Deploy LYXRegistrar contract
        lyxRegistrar = new LYXRegistrar(
            unsRegistry,
            LYX_NAMEHASH,
            "LYX Names",
            "LYXN",
            address(this),
            address(0)
        );

        // Setting LYXRegistrar as the owner of the LYX namehash
        unsRegistry.setSubNameOwner(
            bytes32(0),
            keccak256("lyx"),
            address(lyxRegistrar)
        );

        // Deploy the ReservedNamesController and set this test contract as the owner
        reservedNamesController = new ReservedNamesController(
            lyxRegistrar,
            address(this)
        );

        // Forward time if necessary (optional)
        uint256 timeToForward = 900 days;
        vm.warp(block.timestamp + timeToForward);

        // Add this contract as a controller to lyxRegistrar
        lyxRegistrar.addController(address(reservedNamesController));
    }

    function testNonOwnerCannotReserveSingleName() public {
        string memory name = "nonownername";
        address nonOwner = address(0xABC);
        uint256 duration = 365 days;

        vm.prank(nonOwner);
        vm.expectRevert();
        reservedNamesController.reserve(name, nonOwner, duration);
    }

    function testNonOwnerCannotReserveMultipleNames() public {
        string[] memory names = new string[](2);
        names[0] = "nonownername1";
        names[1] = "nonownername2";
        address nonOwner = address(0xABC);
        uint256 duration = 365 days;

        vm.prank(nonOwner);
        vm.expectRevert();
        reservedNamesController.reserve(names, nonOwner, duration);
    }

    function testReserveSingleName() public {
        string memory name = "reservedname";
        address ownerOfReservedName = address(0x123);
        uint256 duration = 365 days;

        reservedNamesController.reserve(name, ownerOfReservedName, duration);

        bytes32 label = keccak256(bytes(name));
        assertEq(lyxRegistrar.tokenOwnerOf(label), ownerOfReservedName);

        address nodeOwner = unsRegistry.owner(node(label));
        assertEq(nodeOwner, ownerOfReservedName);
    }

    function testReserveMultipleNames() public {
        string[] memory names = new string[](2);
        names[0] = "batchname1";
        names[1] = "batchname2";
        address ownerOfReservedNames = address(0x456);
        uint256 duration = 365 days;

        reservedNamesController.reserve(names, ownerOfReservedNames, duration);

        for (uint256 i = 0; i < names.length; i++) {
            bytes32 label = keccak256(bytes(names[i]));
            assertEq(lyxRegistrar.tokenOwnerOf(label), ownerOfReservedNames);
        }
    }

    function testSettingOwnerAsReservedNamesControllerReverts() public {
        string memory name = "invalidname";
        uint256 duration = 365 days;

        vm.expectRevert(); // Specify the expected revert message or condition if available
        reservedNamesController.reserve(
            name,
            address(reservedNamesController),
            duration
        );
    }

    // Additional tests can be added here

    function node(bytes32 labelHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(LYX_NAMEHASH, labelHash));
    }
}
