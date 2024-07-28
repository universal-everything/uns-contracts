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
        reservedNamesController.reserve(
            name,
            nonOwner,
            duration,
            address(0),
            new bytes[](0)
        );
    }

    function testNonOwnerCannotReserveMultipleNames() public {
        string[] memory names = new string[](2);
        names[0] = "nonownername1";
        names[1] = "nonownername2";
        address[] memory owners = new address[](2);
        owners[0] = address(0x123);
        owners[1] = address(0x234);
        uint256[] memory durations = new uint256[](2);
        durations[0] = 365 days;
        durations[1] = 365 days;
        address nonOwner = address(0xABC);
        uint256 duration = 365 days;
        address[] memory resolvers = new address[](2);
        resolvers[0] = address(0);
        resolvers[1] = address(0);
        bytes[][] memory resolverData = new bytes[][](2);
        resolverData[0] = new bytes[](0);
        resolverData[1] = new bytes[](0);

        vm.prank(nonOwner);
        vm.expectRevert();
        reservedNamesController.reserve(
            names,
            owners,
            durations,
            resolvers,
            resolverData
        );
    }

    function testReserveSingleName() public {
        string memory name = "reservedname";
        address ownerOfReservedName = address(0x123);
        uint256 duration = 365 days;

        reservedNamesController.reserve(
            name,
            ownerOfReservedName,
            duration,
            address(0),
            new bytes[](0)
        );

        bytes32 label = keccak256(bytes(name));
        assertEq(lyxRegistrar.tokenOwnerOf(label), ownerOfReservedName);

        address nodeOwner = unsRegistry.owner(node(label));
        assertEq(nodeOwner, ownerOfReservedName);
    }

    function testReserveMultipleNames() public {
        string[] memory names = new string[](2);
        names[0] = "batchname1";
        names[1] = "batchname2";
        address[] memory owners = new address[](2);
        owners[0] = address(0x123);
        owners[1] = address(0x234);
        uint256[] memory durations = new uint256[](2);
        durations[0] = 365 days;
        durations[1] = 365 days;
        address[] memory resolvers = new address[](2);
        resolvers[0] = address(0);
        resolvers[1] = address(0);
        bytes[][] memory resolverData = new bytes[][](2);
        resolverData[0] = new bytes[](0);
        resolverData[1] = new bytes[](0);

        reservedNamesController.reserve(
            names,
            owners,
            durations,
            resolvers,
            resolverData
        );

        for (uint256 i = 0; i < names.length; i++) {
            bytes32 label = keccak256(bytes(names[i]));
            assertEq(lyxRegistrar.tokenOwnerOf(label), owners[i]);
        }
    }

    function testSettingOwnerAsReservedNamesControllerReverts() public {
        string memory name = "invalidname";
        uint256 duration = 365 days;

        vm.expectRevert(); // Specify the expected revert message or condition if available
        reservedNamesController.reserve(
            name,
            address(reservedNamesController),
            duration,
            address(0),
            new bytes[](0)
        );
    }

    // Additional tests can be added here

    function node(bytes32 labelHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(LYX_NAMEHASH, labelHash));
    }
}
