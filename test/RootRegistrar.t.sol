// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "forge-std/Test.sol";
import "../contracts/RootRegistrar/RootRegistrar.sol";
import "../contracts/UNSRegistry/UNSRegistry.sol";

contract RootRegistrarTest is Test {
    RootRegistrar rootRegistrar;
    address mockUNSRegistry;
    address owner;
    address controller;

    function setUp() public {
        mockUNSRegistry = address(new UNSRegistry(address(this)));
        owner = address(1);
        controller = address(2);
        rootRegistrar = new RootRegistrar(mockUNSRegistry, owner);
        UNSRegistry(mockUNSRegistry).setOwner(
            bytes32(0),
            address(rootRegistrar)
        );
    }

    function testInitialization() public {
        assertEq(rootRegistrar.UNSRegistry(), mockUNSRegistry);
        assertTrue(rootRegistrar.isController(owner));
        assertEq(rootRegistrar.owner(), owner);
    }

    function testAddRemoveController() public {
        // Add a new controller
        vm.prank(owner);
        rootRegistrar.addController(controller);
        assertTrue(rootRegistrar.isController(controller));

        // Remove the controller
        vm.prank(owner);
        rootRegistrar.removeController(controller);
        assertFalse(rootRegistrar.isController(controller));
    }

    function testSetResolverByOwner() public {
        address resolver = address(3);

        vm.prank(owner);
        rootRegistrar.setResolver(resolver);

        // Check resolver set in mock UNSRegistry
        assertEq(UNSRegistry(mockUNSRegistry).resolver(bytes32(0)), resolver);
    }

    function testSetResolverByRandom() public {
        address caller = address(9);
        address resolver = address(3);

        vm.prank(caller);
        vm.expectRevert();
        rootRegistrar.setResolver(resolver);
    }

    function testLockAndUnlockTLD() public {
        bytes32 label = keccak256("example");

        // Lock the TLD
        vm.prank(owner);
        rootRegistrar.lock(label);
        assertTrue(rootRegistrar.isLocked(label));
    }

    function testSetSubNameOwner() public {
        bytes32 label = keccak256("subname");
        address newOwner = address(4);

        vm.prank(owner);
        rootRegistrar.setSubNameOwner(label, newOwner);

        // Check owner set in mock UNSRegistry
        bytes32 subNameHash = keccak256(abi.encodePacked(bytes32(0), label));
        assertEq(UNSRegistry(mockUNSRegistry).owner(subNameHash), newOwner);
    }

    function testSetSubNameOwnerRevertWhenNameIsLocked() public {
        bytes32 label = keccak256("second");
        // Lock the TLD
        vm.prank(owner);
        rootRegistrar.lock(label);
        assertTrue(rootRegistrar.isLocked(label));

        address newOwner = address(4);

        vm.prank(owner);
        vm.expectRevert();
        rootRegistrar.setSubNameOwner(label, newOwner);
    }

    function testSetSubNameOwnerRevertRandom() public {
        bytes32 label = keccak256("second");
        address caller = address(9);
        address newOwner = address(4);

        vm.prank(caller);
        vm.expectRevert();
        rootRegistrar.setSubNameOwner(label, newOwner);
    }
}
