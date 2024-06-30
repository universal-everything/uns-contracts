// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

// interfaces
import "./ILYXRegistrar.sol";
import "../UNSRegistry/IUNSRegistry.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP1UniversalReceiver/ILSP1UniversalReceiver.sol";

// libraries
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// modules
import "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";

// constants

import "@lukso/lsp-smart-contracts/contracts/LSP4DigitalAssetMetadata/LSP4Constants.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP1UniversalReceiver/LSP1Constants.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8Constants.sol";
import "./LYXRegistrarConstants.sol";

// errors
import "@erc725/smart-contracts/contracts/errors.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8Errors.sol";
import "./LYXRegistrarErrors.sol";

/**
 * @title LYXRegistrar interface
 * @notice This is an interface for the registrar managing the LYX node. It includes
 * the ability to add or remove controllers, register and renew names, and
 * manage name ownership. The registered names will be LSP8 assets that can be
 * transferred and traded.
 *
 * @dev The getter functions such as `balanceOf`, `tokenIdsOf`, and `getOperatorsOf` does not account for expired labels.
 * If a label has expired, it will still be included in the returned values.
 */
contract LYXRegistrar is LSP8IdentifiableDigitalAsset, ILYXRegistrar {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    IUNSRegistry public immutable UNS_Registry;
    bytes32 public immutable LYX_NAME_HASH;

    /// @notice A mapping of token IDs to their respective expiry times
    mapping(bytes32 => uint256) private _expiries;

    /// @notice grace period in which the owner can't edit the records but can still re-register the name.
    uint256 public constant GRACE_PERIOD = 90 days;

    /// @notice A list of controller addresses
    EnumerableSet.AddressSet private _controllers;

    /// @dev Maps labelHash to their respective timestamps of when they were marked for burning.
    mapping(bytes32 => uint256) private _unregisterTimestamp;

    /// @dev Address of the contract responsible for NFT metadata description.
    address private _nftDescriptor;

    /// @dev Address authorized to set or change the NFT descriptor contract.
    address private _nftDescriptorSetter;

    /// @dev A variable gas value that can be adjusted for specific contract functions.
    uint256 private _changeableGasValue;

    /**
     * @notice Ensures that the caller is a controller
     * @dev Throws if the caller is not a controller
     */
    modifier onlyController() {
        if (!_controllers.contains(msg.sender)) revert CallerIsNotController();
        _;
    }

    /// @notice Constructs a new LSP8 Compliant - LYXRegistrar contract
    /// @param _UNS_Registry The Universal Name System Registry contract instance
    /// @param _LYX_NAME_HASH The namehash of the TLD this registrar owns (e.g., .lyx)
    /// @param newOwner_ The owner of the contract
    constructor(
        IUNSRegistry _UNS_Registry,
        bytes32 _LYX_NAME_HASH,
        string memory tokenName,
        string memory tokenSymbol,
        address newOwner_,
        address nftdescriptor_
    ) LSP8IdentifiableDigitalAsset(tokenName, tokenSymbol, newOwner_, 1, 4) {
        UNS_Registry = _UNS_Registry;
        LYX_NAME_HASH = _LYX_NAME_HASH;
        _changeableGasValue = 750000;
        _nftDescriptorSetter = newOwner_;
        _nftDescriptor = nftdescriptor_;
    }

    /// @return The list of controllers
    function getControllers() external view returns (address[] memory) {
        return _controllers.values();
    }

    /// @param _addr The address to check
    /// @return True if the address is a controller
    function isController(address _addr) external view returns (bool) {
        return _controllers.contains(_addr);
    }

    /// @notice Authorizes a controller, who can register and renew domains.
    /// @dev Adds a controller to the list of authorized controllers.
    /// @param controller The address of the controller to be added.
    function addController(address controller) external onlyOwner {
        _controllers.add(controller);
        emit ControllerAdded(controller);
    }

    /// @notice Revokes controller permission for an address.
    /// @dev Removes a controller from the list of authorized controllers.
    /// @param controller The address of the controller to be removed.
    function removeController(address controller) external onlyOwner {
        _controllers.remove(controller);
        emit ControllerRemoved(controller);
    }

    /// @notice Sets the resolver for the TLD this registrar manages.
    /// @dev Sets the address of the resolver contract.
    /// @param resolver The address of the resolver.
    function setLYXRegistrarResolver(address resolver) external onlyOwner {
        UNS_Registry.setResolver(LYX_NAME_HASH, resolver);
    }

    /// @notice Returns the address of the NFT metadata descriptor contract.
    /// @return The address of the NFT descriptor contract.
    function getNftDescriptor() external view returns (address) {
        return _nftDescriptor;
    }

    /// @notice Returns the address authorized to set or change the NFT descriptor contract.
    /// @return The address authorized for setting the NFT descriptor.
    function getNftDescriptorSetter() external view returns (address) {
        return _nftDescriptorSetter;
    }

    /// @notice Retrieves the timestamp of when a name was marked for unregistering.
    /// @dev Returns the unregister timestamp for a given labelHash.
    /// @param labelHash The hash of the label to query the unregister timestamp for.
    /// @return The timestamp of when the name associated with the given labelHash was marked for burning.
    function getUnregisterTimestamp(
        bytes32 labelHash
    ) public view returns (uint256) {
        return _unregisterTimestamp[labelHash];
    }

    /// @notice Retrieves the current changeable gas value.
    /// @dev Returns the current value of the _changeableGasValue variable.
    /// @return The current changeable gas value.
    function getChangeableGasValue() public view returns (uint256) {
        return _changeableGasValue;
    }

    /*//////////////////////////////////////////////////////////////
                        Name Management Logic
    //////////////////////////////////////////////////////////////*/

    function isActive(bytes32 nameLabelHash) external view returns (bool) {
        return !available(nameLabelHash);
    }

    /// @notice Returns the expiration timestamp of the specified label hash.
    /// @dev Retrieves the expiration timestamp for the given name.
    /// @param nameLabelHash The label hash of the name.
    /// @return The expiration timestamp of the name.
    function nameExpires(
        bytes32 nameLabelHash
    ) external view returns (uint256) {
        return _expiries[nameLabelHash];
    }

    /// @notice Returns true if the specified name is available for registration.
    /// @dev Checks if the given name is available for registration.
    /// @param nameLabelHash The label hash of the name.
    /// @return A boolean indicating if the name is available.
    function available(bytes32 nameLabelHash) public view returns (bool) {
        return _expiries[nameLabelHash] + GRACE_PERIOD < block.timestamp;
    }

    /// @notice Register a name
    /// @dev This function registers a name and modifies the registry
    /// @param nameLabelHash The token nameLabelHash (keccak256 of the label)
    /// @param _owner The address that should own the registration
    /// @param duration Duration in seconds for the registration
    /// @return uint256 The new expiration timestamp of the registered name
    function register(
        bytes32 nameLabelHash,
        address _owner,
        bytes memory ownerData,
        address _resolver,
        bytes32[] memory resolverDataKeys,
        bytes[] memory resolverDataValues,
        uint256 duration
    ) external override onlyController returns (uint256) {
        if (!available(nameLabelHash)) revert NameNotAvailable(nameLabelHash);

        _expiries[nameLabelHash] = block.timestamp + duration;
        delete _unregisterTimestamp[nameLabelHash];

        if (resolverDataKeys.length == 0 || resolverDataValues.length == 0) {
            UNS_Registry.setSubNameRecord(
                LYX_NAME_HASH,
                nameLabelHash,
                _owner,
                _resolver,
                0
            );
        } else {
            UNS_Registry.setSubNameRecordWithResolverData(
                LYX_NAME_HASH,
                nameLabelHash,
                _owner,
                _resolver,
                0,
                resolverDataKeys,
                resolverDataValues
            );
        }

        // Name was previously owned, and expired
        if (_exists(nameLabelHash)) _burn(nameLabelHash, bytes("Expired"));

        // Minting the name after burning it
        _mint(_owner, nameLabelHash, true, ownerData);

        emit NameRegistered(
            nameLabelHash,
            _owner,
            _resolver,
            block.timestamp + duration
        );

        return block.timestamp + duration;
    }

    /// @notice Renew a name's registration
    /// @param nameLabelHash The token nameLabelHash (keccak256 of the label) to renew the registration of
    /// @param duration Duration in seconds to extend the registration
    /// @return uint256 The new expiration timestamp of the renewed name
    function renew(
        bytes32 nameLabelHash,
        uint256 duration
    ) external override onlyController returns (uint256) {
        // Name must be registered here or in grace period
        if (available(nameLabelHash)) revert RenewalPeriodEnded(nameLabelHash);
        _expiries[nameLabelHash] += duration;
        emit NameRenewed(nameLabelHash, _expiries[nameLabelHash]);
        return _expiries[nameLabelHash];
    }

    /// @notice Unregister a name and sets its expiration to the current timestamp
    /// @param nameLabelHash The token nameLabelHash (keccak256 of the label) to unregister
    function unregister(bytes32 nameLabelHash) external {
        if (!_isOperatorOrOwner(msg.sender, nameLabelHash))
            revert LSP8NotTokenOperator(nameLabelHash, msg.sender);

        if (_unregisterTimestamp[nameLabelHash] == 0) {
            _unregisterTimestamp[nameLabelHash] = block.timestamp;
        } else {
            if (_unregisterTimestamp[nameLabelHash] + 2400 > block.timestamp)
                revert CannotUnregisterYet(nameLabelHash);
            _unregisterTimestamp[nameLabelHash] = 0;
            // Set the expiration to the current block timestamp
            // Doesn't make it directly available, don't burn it directly
            _expiries[nameLabelHash] = block.timestamp;

            emit NameBurned(nameLabelHash);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        Token specific Logic
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the owner of the specified token nameLabelHash. Names become unowned
    ///         when their registration expires
    /// @dev Overridden from LSP8 to make the tokenId unowned when their registration expires
    /// @param tokenId The tokenId (keccak256 of label) to query the owner of
    /// @return address Currently marked as the owner of the given token nameLabelHash
    function tokenOwnerOf(
        bytes32 tokenId
    ) public view virtual override returns (address) {
        if (_expiries[tokenId] <= block.timestamp) revert NameExpired(tokenId);
        return super.tokenOwnerOf(tokenId);
    }

    /// @notice Check if the caller is an operator or owner of the specified token nameLabelHash
    /// @dev This function overrides the original `_isOperatorOrOwner` from the LSP8 standard
    ///      It requires that the token nameLabelHash is not expired before checking if the caller is an operator or owner
    /// @param caller The address of the caller to be checked
    /// @param tokenId The token nameLabelHash to query the operator or owner status of
    /// @return bool True if the caller is an operator or owner, false otherwise
    function _isOperatorOrOwner(
        address caller,
        bytes32 tokenId
    ) internal view virtual override returns (bool) {
        if (_expiries[tokenId] <= block.timestamp) revert NameExpired(tokenId);
        return super._isOperatorOrOwner(caller, tokenId);
    }

    /**
     * @notice Set the resolver for the TLD this registrar manages (.LYX)
     * @dev Can only be called by the contract owner
     * @param changeableGasValue_ The address of the resolver to be set
     */
    function setMaxBurnGas(
        uint256 changeableGasValue_
    ) external virtual onlyOwner {
        _changeableGasValue = changeableGasValue_;
        emit MaxBurnGasChanged(changeableGasValue_);
    }

    /// @notice Changes the NFT descriptor to a new address.
    /// @dev Can only be called by the current NFT descriptor setter.
    /// @param _newDescriptor The address of the new NFT descriptor.
    function changeNFTDescriptor(address _newDescriptor) external {
        if (msg.sender != _nftDescriptorSetter) revert NotNFTDescriptorSetter();

        emit NFTDescriptorChanged(_nftDescriptor, _newDescriptor);
        _nftDescriptor = _newDescriptor;
    }

    /// @notice Changes the NFT descriptor setter to a new address.
    /// @dev Can only be called by the current NFT descriptor setter.
    /// @param _newSetter The address of the new NFT descriptor setter.
    function changeNFTDescriptorSetter(address _newSetter) external {
        address oldSetter = _nftDescriptorSetter;
        if (msg.sender != oldSetter) revert NotNFTDescriptorSetterSetter();

        _nftDescriptorSetter = _newSetter;
        emit NFTDescriptorSetterChanged(oldSetter, _newSetter);
    }

    /// @dev override the function to allow setting the LYX_REGISTRAR_TOKENID_NAME by anyone
    /// as long as the hash of the data set is equal to the tokenId value
    function _setDataForTokenId(
        bytes32 tokenId,
        bytes32 dataKey,
        bytes memory dataValue
    ) internal override {
        if (dataKey != LYX_REGISTRAR_TOKENID_NAME && msg.sender != owner()) {
            revert OwnableCallerNotTheOwner(msg.sender);
        }

        if (dataKey == LYX_REGISTRAR_TOKENID_NAME) {
            if (keccak256(dataValue) != tokenId)
                revert LabelHashIsNotValid(tokenId, dataValue);
        }

        super._setDataForTokenId(tokenId, dataKey, dataValue);
    }

    /// @dev override the function to allow setting specific dataKey by non owner with certain conditions
    function setDataForTokenId(
        bytes32 tokenId,
        bytes32 dataKey,
        bytes memory dataValue
    ) public virtual override {
        _setDataForTokenId(tokenId, dataKey, dataValue);
    }

    /// @dev override the function to allow setting specific dataKey by non owner with certain conditions
    function setDataBatchForTokenIds(
        bytes32[] memory tokenIds,
        bytes32[] memory dataKeys,
        bytes[] memory dataValues
    ) public virtual override {
        if (
            tokenIds.length != dataKeys.length ||
            dataKeys.length != dataValues.length
        ) {
            revert LSP8TokenIdsDataLengthMismatch();
        }

        if (tokenIds.length == 0) {
            revert LSP8TokenIdsDataEmptyArray();
        }

        for (uint256 i; i < tokenIds.length; ) {
            _setDataForTokenId(tokenIds[i], dataKeys[i], dataValues[i]);

            // Increment the iterator in unchecked block to save gas
            unchecked {
                ++i;
            }
        }
    }

    /// @dev override the _getDataForTokenId to return the token URI for the tokenId from a function
    /// without being stored for each tokenId
    function _getDataForTokenId(
        bytes32 tokenId,
        bytes32 dataKey
    ) internal view override returns (bytes memory) {
        if (dataKey == _LSP4_METADATA_KEY) {
            return _constructTokenIdURI(tokenId);
        }
        return super._getDataForTokenId(tokenId, dataKey);
    }

    function _constructTokenIdURI(
        bytes32 tokenId
    ) internal view virtual returns (bytes memory) {
        // To be implemented once svg is complete
        // Read LYX_REGISTRAR_TOKENID_NAME
        // Probably INFTDescriptor(nftDescriptorVariable).tokenURI();
    }

    /// @dev override the after token transfer hook to change the subname owner in the registry
    /// only in case of transfer between two different addresses (not minting or burning)
    function _afterTokenTransfer(
        address from,
        address to,
        bytes32 tokenId,
        bytes memory /*data*/
    ) internal virtual override {
        if (from != address(0) && to != address(0)) {
            UNS_Registry.setSubNameOwner(LYX_NAME_HASH, tokenId, to);
            delete _unregisterTimestamp[tokenId];
        }
    }

    /// @dev Override the burn to call the LSP1 universal receiver with specific amount
    /// of gas, to avoid the original owner blocking the burn when a name expire
    function _burn(
        bytes32 tokenId,
        bytes memory data
    ) internal virtual override {
        address tokenOwner = tokenOwnerOf(tokenId);

        // token being burned
        --_existingTokens;

        _clearOperators(tokenOwner, tokenId);

        _ownedTokens[tokenOwner].remove(tokenId);
        delete _tokenOwners[tokenId];

        emit Transfer(msg.sender, tokenOwner, address(0), tokenId, false, data);

        bytes memory lsp1Data = abi.encode(
            msg.sender,
            tokenOwner,
            address(0),
            tokenId,
            data
        );

        if (
            ERC165Checker.supportsERC165InterfaceUnchecked(
                tokenOwner,
                _INTERFACEID_LSP1
            )
        ) {
            uint256 changeableGasValue = _changeableGasValue;

            // Encoding the function selector and arguments
            bytes memory payload = abi.encodeWithSelector(
                ILSP1UniversalReceiver.universalReceiver.selector,
                _TYPEID_LSP8_TOKENSSENDER,
                lsp1Data
            );

            assembly {
                // Perform the call
                let success := call(
                    changeableGasValue,
                    tokenOwner,
                    0,
                    add(payload, 32),
                    mload(payload),
                    0,
                    0
                )
            }
        }
    }
}
