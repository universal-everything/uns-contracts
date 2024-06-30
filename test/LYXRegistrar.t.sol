// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/UNSRegistry/UNSRegistry.sol";
import "../contracts/UNSRegistry/IUNSRegistry.sol";
import "../contracts/Resolver/DefaultResolver.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP4DigitalAssetMetadata/LSP4Constants.sol";
import "../contracts/LYXRegistrar/LYXRegistrar.sol";
import "./Mocks/UnlimitedGasLSP1.sol";
import "./Mocks/ReverterLSP1.sol";

contract LYXRegistrarTest is Test {
    UNSRegistry unsRegistry;
    LYXRegistrar public lyxRegistrar;
    DefaultResolver public defaultResolver;
    bytes32 constant LYX_NAMEHASH =
        keccak256(abi.encodePacked(bytes32(0), keccak256("lyx")));

    function setUp() public {
        // Deploy UNS Registry
        unsRegistry = new UNSRegistry(address(this));

        // Deploy Default Resolver
        defaultResolver = new DefaultResolver(unsRegistry);

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

        uint256 timeToForward = 900 days; // Set the time you want to forward
        uint256 newTimestamp = block.timestamp + timeToForward;
        vm.warp(newTimestamp); // Forward the block timestamp
    }

    function testRemoveController() public {
        address controllerToAdd = address(0xABC);
        address controllerToRemove = address(0x123);

        // Add two controllers
        lyxRegistrar.addController(controllerToAdd);
        lyxRegistrar.addController(controllerToRemove);

        // Verify that both addresses are controllers
        assertTrue(lyxRegistrar.isController(controllerToAdd));
        assertTrue(lyxRegistrar.isController(controllerToRemove));

        // Remove one controller
        lyxRegistrar.removeController(controllerToRemove);

        // Verify that the removed address is no longer a controller
        assertFalse(lyxRegistrar.isController(controllerToRemove));
        // Verify that the other controller still exists
        assertTrue(lyxRegistrar.isController(controllerToAdd));
    }

    function testNonControllerCannotRegister() public {
        address nonController = address(1);
        bytes32 labelHash = keccak256("test");
        uint256 duration = 365 days;

        vm.prank(nonController);
        vm.expectRevert();
        lyxRegistrar.register(
            labelHash,
            nonController,
            "",
            address(0),
            new bytes32[](1),
            new bytes[](1),
            duration
        );
    }

    function testControllerCanRegisterAndVerify() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("validname");
        uint256 duration = 365 days;
        address domainOwner = address(0x780);

        // Add the current contract as a controller
        lyxRegistrar.addController(controller);

        // Register a domain using the controller address
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            duration
        );

        // Verify that the domain is registered
        assertEq(lyxRegistrar.tokenOwnerOf(labelHash), domainOwner);
        assertFalse(lyxRegistrar.available(labelHash));
        assertEq(
            lyxRegistrar.nameExpires(labelHash),
            block.timestamp + duration
        );

        // Verify the changes in the UNS registry
        address owner = unsRegistry.owner(node(labelHash));
        assertEq(owner, domainOwner);
    }

    function testControllerCannotRegisterAlreadyRegisteredName() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("alreadyregistered");
        uint256 duration = 365 days;
        address domainOwner = address(0x123);

        // Add the current contract as a controller
        lyxRegistrar.addController(controller);

        // Register a domain name for the first time
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            duration
        );

        // Attempt to register the same domain name again and expect a revert
        vm.expectRevert();
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            duration
        );
    }

    function testControllerCanRegisterNameAfterExpiration() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("expiringname");
        uint256 initialDuration = 1 days;
        address domainOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Register a domain name
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            initialDuration
        );

        // Verify the changes in the UNS registry
        address owner1 = unsRegistry.owner(node(labelHash));
        assertEq(owner1, domainOwner);

        // Fast forward time to after the expiration of the domain
        vm.warp(block.timestamp + GRACE_PERIOD + initialDuration + 1);
        assertTrue(lyxRegistrar.available(labelHash));

        // Register the same domain name again after expiration
        address newOwner = address(0x456);
        lyxRegistrar.register(
            labelHash,
            newOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            initialDuration
        );

        assertEq(lyxRegistrar.tokenOwnerOf(labelHash), newOwner);
        assertFalse(lyxRegistrar.available(labelHash));

        // Verify the changes in the UNS registry
        address owner2 = unsRegistry.owner(node(labelHash));
        assertEq(owner2, newOwner);
    }

    function testDomainNotAvailableUntilAfterGracePeriod() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("expiringsoon");
        uint256 registrationDuration = 1 days;
        address initialOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Register a domain name
        lyxRegistrar.register(
            labelHash,
            initialOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        // Fast forward time to the point of expiration but before the grace period ends
        vm.warp(block.timestamp + registrationDuration);

        // Attempt to register the domain again during the grace period
        address newOwner = address(0x456);
        vm.expectRevert();
        lyxRegistrar.register(
            labelHash,
            newOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );
    }

    function testTokenIdRevertsAfterExpiration() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("expiringdomain");
        uint256 registrationDuration = 1 days;
        address initialOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Register a domain name
        lyxRegistrar.register(
            labelHash,
            initialOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        // Fast forward time beyond the expiration and grace period
        vm.warp(block.timestamp + registrationDuration + 1);

        // Attempt to access token-related information and expect a revert
        vm.expectRevert();
        lyxRegistrar.tokenOwnerOf(labelHash);
    }

    function testTransferOfExpiredDomainShouldRevert() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("expiringdomain");
        uint256 registrationDuration = 1 days;
        address initialOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Register a domain name
        lyxRegistrar.register(
            labelHash,
            initialOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        // Fast forward time to after the domain expiration
        vm.warp(block.timestamp + registrationDuration + 1);

        // Attempt to transfer the domain after expiration, expecting a revert
        address newOwner = address(0x456);
        vm.expectRevert();
        vm.prank(initialOwner);
        lyxRegistrar.transfer(initialOwner, newOwner, labelHash, true, "");
    }

    function testControllerRenewsDomainName() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("renewabledomain");
        uint256 initialDuration = 365 days;
        uint256 renewalDuration = 365 days;
        address domainOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Register a domain name
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            initialDuration
        );

        // Fast forward time but not past the expiration
        vm.warp(block.timestamp + initialDuration - 30 days);
        uint256 currentBlockTimestamp = block.timestamp;
        // Renew the domain name
        lyxRegistrar.renew(labelHash, renewalDuration);

        // Check the new expiration time
        uint256 newExpirationTime = lyxRegistrar.nameExpires(labelHash);
        uint256 expectedExpirationTime = currentBlockTimestamp +
            30 days +
            renewalDuration;
        assertEq(newExpirationTime, expectedExpirationTime);
    }

    function testNonControllerCannotRenew() public {
        address controller = address(this);
        address nonController = address(0xABC);
        bytes32 labelHash = keccak256("domainrenewal");
        uint256 registrationDuration = 365 days;

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            controller,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        // Attempt to renew the domain by a non-controller, expecting a revert
        vm.prank(nonController);
        vm.expectRevert();
        lyxRegistrar.renew(labelHash, registrationDuration);
    }

    function testControllerCanRenewAfterExpirationWithinGracePeriod() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("domainrenewalgrace");
        uint256 registrationDuration = 1 days;
        uint256 gracePeriod = 90 days; // Assuming a 90-day grace period

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            controller,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        // Fast forward time just past expiration but within the grace period
        vm.warp(block.timestamp + registrationDuration + 1);

        // Controller renews the domain within the grace period
        vm.prank(controller);
        lyxRegistrar.renew(labelHash, registrationDuration);
    }

    function testControllerCannotRenewAfterExpirationAndGracePeriod() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("domainexpired");
        uint256 registrationDuration = 1 days;
        uint256 gracePeriod = 90 days; // Assuming a 90-day grace period

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            controller,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        // Fast forward time beyond the expiration and grace period
        vm.warp(block.timestamp + registrationDuration + gracePeriod + 1);

        // Attempt to renew the domain after the grace period, expecting a revert
        vm.prank(controller);
        vm.expectRevert();
        lyxRegistrar.renew(labelHash, registrationDuration);
    }

    function testUnregisterDomainDirectlyRevert() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("unregisterdomain");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        vm.prank(domainOwner);
        vm.expectRevert();
        lyxRegistrar.unregister(labelHash);
    }

    function testUnregisterDomainLessThanBurnTimeRevert() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("unregisterdomain");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        vm.warp(block.timestamp + 2300);

        vm.prank(domainOwner);
        vm.expectRevert();
        lyxRegistrar.unregister(labelHash);
    }

    function testUnregisterDomainAfterBurnTime() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("unregisterdomain");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        vm.warp(block.timestamp + 2400);

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        assertEq(lyxRegistrar.nameExpires(labelHash), block.timestamp);
        assertFalse(lyxRegistrar.available(labelHash));
    }

    function testUnregisterDomainAfterBurnTimeCannotBeRegisteredDirectly()
        public
    {
        address controller = address(this);
        bytes32 labelHash = keccak256("unregisterdomain");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        vm.warp(block.timestamp + 2400);

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        address random = address(0x456);

        vm.expectRevert();
        lyxRegistrar.register(
            labelHash,
            random,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );
    }

    function testUnregisterDomainAfterBurnTimeCanBeRenewedByController()
        public
    {
        address controller = address(this);
        bytes32 labelHash = keccak256("unregisterdomain");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        vm.warp(block.timestamp + 2400);

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        vm.expectRevert();
        lyxRegistrar.tokenOwnerOf(labelHash);

        // vm.expectRevert();
        lyxRegistrar.renew(labelHash, registrationDuration);

        address owner = lyxRegistrar.tokenOwnerOf(labelHash);
        assertEq(owner, domainOwner);
    }

    function testUnregisterDomainAfterBurnTimeAndGracePeriodCanBeRegisteredByController()
        public
    {
        address controller = address(this);
        bytes32 labelHash = keccak256("unregisterdomain");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        vm.warp(block.timestamp + 2400);

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        vm.expectRevert();
        lyxRegistrar.tokenOwnerOf(labelHash);

        vm.warp(block.timestamp + 90 days + 1);

        address newOwner = address(0x738);
        lyxRegistrar.register(
            labelHash,
            newOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        address owner = lyxRegistrar.tokenOwnerOf(labelHash);
        assertEq(owner, newOwner);
    }

    function testOldOwnerConsumingGasCannotBlockNewRegistration() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("unregisterdomain");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(new UnlimitedGasLSP1());

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        vm.warp(block.timestamp + registrationDuration + 90 days + 1);

        address newDomainOwner = address(0x789);
        lyxRegistrar.register(
            labelHash,
            newDomainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        address owner = lyxRegistrar.tokenOwnerOf(labelHash);
        assertEq(owner, newDomainOwner);
    }

    function testOldOwnerRevertingCannotBlockNewRegistration() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("unregisterdomain");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(new ReverterLSP1());

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        vm.warp(block.timestamp + registrationDuration + 90 days + 1);

        address newDomainOwner = address(0x789);
        lyxRegistrar.register(
            labelHash,
            newDomainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        address owner = lyxRegistrar.tokenOwnerOf(labelHash);
        assertEq(owner, newDomainOwner);
    }

    function testOnlyOwnerCanSetMaxBurnGas() public {
        uint256 newGasValue = 1000000; // Example new gas value
        address nonOwner = address(0xABC);

        lyxRegistrar.setMaxBurnGas(newGasValue);

        vm.prank(nonOwner);
        vm.expectRevert();
        lyxRegistrar.setMaxBurnGas(newGasValue);
    }

    function testOnlyNFTDescriptorSetterCanChangeNFTDescriptor() public {
        address newNFTDescriptor = address(0xABC);
        address nonSetter = address(0x123);

        // First, test that the original setter can successfully call the function
        lyxRegistrar.changeNFTDescriptor(newNFTDescriptor);
        address _nftDescriptor = lyxRegistrar.getNftDescriptor();
        assertEq(_nftDescriptor, newNFTDescriptor);

        vm.prank(nonSetter);
        vm.expectRevert();
        lyxRegistrar.changeNFTDescriptor(newNFTDescriptor);
    }

    function testOnlyNFTDescriptorSetterCanChangeDescriptorSetter() public {
        address newSetter = address(0xABC);
        address nonSetter = address(0x123);

        lyxRegistrar.changeNFTDescriptorSetter(newSetter);

        address _nftDescriptorSetter = lyxRegistrar.getNftDescriptorSetter();
        assertEq(_nftDescriptorSetter, newSetter);

        vm.prank(nonSetter);
        vm.expectRevert();
        lyxRegistrar.changeNFTDescriptorSetter(newSetter);
    }

    function testDomainOwnerTransfersDomain() public {
        bytes32 labelHash = keccak256("transferdomain");
        uint256 registrationDuration = 365 days;
        address initialOwner = address(0x123);
        address newOwner = address(0x456);

        lyxRegistrar.addController(address(this));

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            initialOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        assertEq(lyxRegistrar.tokenOwnerOf(labelHash), initialOwner);

        // Transfer the domain from the initial owner to the new owner
        vm.prank(initialOwner);
        lyxRegistrar.transfer(initialOwner, newOwner, labelHash, true, "");

        // Verify the new owner in the NFT ownership
        assertEq(lyxRegistrar.tokenOwnerOf(labelHash), newOwner);

        // Verify the new owner in the UNS registry
        address owner = unsRegistry.owner(node(labelHash));
        assertEq(owner, newOwner);
    }

    function testOwnerCanChangeLYXResolver() public {
        address newResolver = address(0xABC);

        // Assuming this test contract is the owner of lyxRegistrar
        lyxRegistrar.setLYXRegistrarResolver(newResolver);

        // Verify the resolver change in the UNS registry
        address resolver = unsRegistry.resolver(LYX_NAMEHASH);
        assertEq(resolver, newResolver);
    }

    function testNonOwnerCannotChangeLYXResolver() public {
        address newResolver = address(0xABC);

        // Assuming this test contract is the owner of lyxRegistrar
        vm.prank(address(0x123));
        vm.expectRevert();
        lyxRegistrar.setLYXRegistrarResolver(newResolver);
    }

    function testOwnerCanSetAnyDataKey() public {
        bytes32 tokenId = keccak256("token1");
        bytes32 dataKey = keccak256("customKey");
        bytes memory dataValue = "customValue";

        // Owner sets data for the token
        lyxRegistrar.setDataForTokenId(tokenId, dataKey, dataValue);

        // Verify the data set (assuming a getter function is available)
        bytes memory fetchedData = lyxRegistrar.getDataForTokenId(
            tokenId,
            dataKey
        );
        assertEq(fetchedData, dataValue);
    }

    function testNonOwnerCannotSetNonMetadataKey() public {
        bytes32 tokenId = keccak256("token2");
        bytes32 nonMetadataKey = keccak256("nonMetadataKey");
        bytes memory dataValue = "nonMetadataValue";
        address nonOwner = address(0xABC);

        vm.prank(nonOwner);
        vm.expectRevert();
        lyxRegistrar.setDataForTokenId(tokenId, nonMetadataKey, dataValue);
    }

    function testNonOwnerCanSetMetadataKeyWithValidData() public {
        bytes32 tokenId = keccak256("token3");
        bytes32 metadataKey = LYX_REGISTRAR_TOKENID_NAME;
        bytes memory dataValue = abi.encodePacked("token3");

        address nonOwner = address(0xABC);

        vm.prank(nonOwner);
        lyxRegistrar.setDataForTokenId(tokenId, metadataKey, dataValue);
    }

    function testNonOwnerCannotSetMetadataKeyWithInvalidData() public {
        bytes32 tokenId = keccak256("token4");
        bytes32 metadataKey = LYX_REGISTRAR_TOKENID_NAME;
        bytes memory invalidDataValue = "invalidData";

        address nonOwner = address(0xABC);

        vm.prank(nonOwner);
        vm.expectRevert();
        lyxRegistrar.setDataForTokenId(tokenId, metadataKey, invalidDataValue);
    }

    function testOwnerSetsDataBatchWithMismatchedArrayLengths() public {
        bytes32[] memory tokenIds = new bytes32[](2);
        tokenIds[0] = keccak256("token5");
        tokenIds[1] = keccak256("token6");

        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = keccak256("key1");
        // Only one key provided, but two token IDs

        bytes[] memory dataValues = new bytes[](2);
        dataValues[0] = "value1";
        dataValues[1] = "value2";

        vm.expectRevert();
        lyxRegistrar.setDataBatchForTokenIds(tokenIds, dataKeys, dataValues);
    }

    function testOwnerSetsDataBatchWithEmptyArray() public {
        bytes32[] memory emptyTokenIds = new bytes32[](0);
        bytes32[] memory emptyDataKeys = new bytes32[](0);
        bytes[] memory emptyDataValues = new bytes[](0);

        vm.expectRevert();
        lyxRegistrar.setDataBatchForTokenIds(
            emptyTokenIds,
            emptyDataKeys,
            emptyDataValues
        );
    }

    function testOwnerCanSetMultipleDataKeys() public {
        // Setting up arrays for multiple tokens
        bytes32[] memory tokenIds = new bytes32[](2);
        tokenIds[0] = keccak256("token1");
        tokenIds[1] = keccak256("token2");

        bytes32[] memory dataKeys = new bytes32[](2);
        dataKeys[0] = keccak256("customKey1");
        dataKeys[1] = keccak256("customKey2");

        bytes[] memory dataValues = new bytes[](2);
        dataValues[0] = "customValue1";
        dataValues[1] = "customValue2";

        // Owner sets data for the tokens
        lyxRegistrar.setDataBatchForTokenIds(tokenIds, dataKeys, dataValues);

        // Verify the data set for each token
        for (uint i = 0; i < tokenIds.length; i++) {
            bytes memory fetchedData = lyxRegistrar.getDataForTokenId(
                tokenIds[i],
                dataKeys[i]
            );
            assertEq(fetchedData, dataValues[i]);
        }
    }

    function testNonOwnerCanSetLSP8TOKENIDNAMEDataKeyUsingSetDataBatch()
        public
    {
        // Setting up arrays for multiple tokens
        bytes32[] memory tokenIds = new bytes32[](1);
        tokenIds[0] = keccak256("token3");

        bytes32[] memory dataKeys = new bytes32[](1);
        dataKeys[0] = LYX_REGISTRAR_TOKENID_NAME;

        bytes[] memory dataValues = new bytes[](1);
        dataValues[0] = abi.encodePacked("token3");

        vm.prank(address(0x123));
        lyxRegistrar.setDataBatchForTokenIds(tokenIds, dataKeys, dataValues);

        // Verify the data set for each token
        for (uint i = 0; i < tokenIds.length; i++) {
            bytes memory fetchedData = lyxRegistrar.getDataForTokenId(
                tokenIds[i],
                dataKeys[i]
            );
            assertEq(fetchedData, dataValues[i]);
        }
    }

    function testAuthorizedAddressCanUnregisterDomain() public {
        bytes32 labelHash = keccak256("domainToUnregister");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);
        address authorizedAddress = address(0x456);

        lyxRegistrar.addController(address(this));

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        // Domain owner authorizes another address
        vm.prank(domainOwner);
        lyxRegistrar.authorizeOperator(authorizedAddress, labelHash, "");

        // Authorized address unregisters the domain
        vm.prank(authorizedAddress);
        lyxRegistrar.unregister(labelHash);

        vm.warp(block.timestamp + 2500);

        vm.prank(authorizedAddress);
        lyxRegistrar.unregister(labelHash);

        assertEq(lyxRegistrar.nameExpires(labelHash), block.timestamp);
    }

    function testRegisterWithResolverNoDataKeys() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("domainresolver");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);

        lyxRegistrar.addController(controller);

        // Register the domain with a resolver and no data keys
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(defaultResolver),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        // Verify the domain registration in the UNS registry
        address owner = unsRegistry.owner(node(labelHash));
        address resolver = unsRegistry.resolver(node(labelHash));
        assertEq(owner, domainOwner);
        assertEq(resolver, address(defaultResolver));
    }

    function testRegisterWithResolverAndDataKeys() public {
        bytes32 labelHash = keccak256("domainresolverdata");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);

        bytes32[] memory dataKeys = new bytes32[](1);
        bytes[] memory dataValues = new bytes[](1);
        dataKeys[0] = keccak256("key1");
        dataValues[0] = "value1";

        lyxRegistrar.addController(address(this));

        // Register the domain with a resolver and data keys
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(defaultResolver),
            dataKeys,
            dataValues,
            registrationDuration
        );

        address owner = unsRegistry.owner(node(labelHash));
        address resolver = unsRegistry.resolver(node(labelHash));
        assertEq(owner, domainOwner);
        assertEq(resolver, address(defaultResolver));
        bytes[] memory fetchedData = defaultResolver.getDataBatch(
            node(labelHash),
            dataKeys
        );
        assertEq(fetchedData[0], "value1");
    }

    function testRegisterWithResolverAndUnconsistentDataKeys() public {
        bytes32 labelHash = keccak256("domainresolverdata");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);

        bytes32[] memory dataKeys = new bytes32[](1);
        bytes[] memory dataValues = new bytes[](0);
        dataKeys[0] = keccak256("key1");

        lyxRegistrar.addController(address(this));

        // Register the domain with a resolver and data keys
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(defaultResolver),
            dataKeys,
            dataValues,
            registrationDuration
        );

        address owner = unsRegistry.owner(node(labelHash));
        address resolver = unsRegistry.resolver(node(labelHash));
        assertEq(owner, domainOwner);
        assertEq(resolver, address(defaultResolver));
        bytes[] memory fetchedData = defaultResolver.getDataBatch(
            node(labelHash),
            dataKeys
        );
        assertEq(fetchedData[0], "");
    }

    function testUnregistrationTimestampResetOnTransfer() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("toBeUnregisered");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);
        address newDomainOwner = address(0x456);

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        uint256 initialDuration = lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        vm.warp(block.timestamp + 2500);
        vm.prank(domainOwner);
        lyxRegistrar.transfer(domainOwner, newDomainOwner, labelHash, true, "");

        vm.prank(newDomainOwner);
        lyxRegistrar.unregister(labelHash);

        assertEq(lyxRegistrar.nameExpires(labelHash), initialDuration);
    }

    function testUnregistrationTimestampResetOnNewRegistration() public {
        address controller = address(this);
        bytes32 labelHash = keccak256("toBeUnregisered");
        uint256 registrationDuration = 365 days;
        address domainOwner = address(0x123);
        address newDomainOwner = address(0x456);

        lyxRegistrar.addController(controller);

        // Controller registers the domain
        lyxRegistrar.register(
            labelHash,
            domainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        vm.prank(domainOwner);
        lyxRegistrar.unregister(labelHash);

        vm.warp(block.timestamp + 366 days + 91 days);

        // Controller registers the domain
        uint256 newDuration = lyxRegistrar.register(
            labelHash,
            newDomainOwner,
            "",
            address(0),
            new bytes32[](0),
            new bytes[](0),
            registrationDuration
        );

        vm.prank(newDomainOwner);
        lyxRegistrar.unregister(labelHash);

        assertEq(lyxRegistrar.nameExpires(labelHash), newDuration);
    }

    uint256 public constant GRACE_PERIOD = 90 days;

    function node(bytes32 labelHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(LYX_NAMEHASH, labelHash));
    }
}
