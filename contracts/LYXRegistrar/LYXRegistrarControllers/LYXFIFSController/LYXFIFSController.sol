// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4;

import {IPriceOracle} from "./PriceOracle/IPriceOracle.sol";
import {ILYXFIFSController} from "./ILYXFIFSController.sol";
import {LYXRegistrar} from "../../LYXRegistrar.sol";
import {LYX_REGISTRAR_TOKENID_NAME} from "../../LYXRegistrarConstants.sol";
import {ReverseRegistrar} from "../../../ReverseRegistrar/ReverseRegistrar.sol";
import {StringUtils} from "../../../Utils/StringUtils.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @title A controller for the LYX registrar
/// @notice This contract allows users to register and renew .LYX names
contract LYXFIFSController is Ownable, ILYXFIFSController {
    using StringUtils for *;

    bytes32 constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    bytes32 constant LYX_NAME_HASH =
        0x94cfba061608af7c48de54c601c78a4e2682021535e4b15c0c0c681b65d5315d;

    bytes32 constant lookup =
        0x3031323334353637383961626364656600000000000000000000000000000000;

    /// @dev Minimum registration duration for a UNS name
    uint256 public constant MIN_REGISTRATION_DURATION = 28 days;
    uint256 public constant MAX_REGISTRATION_DURATION = 366 days;

    /// @notice Reference to the base registrar contract
    LYXRegistrar public immutable LYX_REGISTRAR;

    /// @notice Reference to the Reverse registrar contract
    ReverseRegistrar public immutable REVERSE_REGISTRAR;

    /// @notice Minimum commitment age in seconds
    uint256 public minCommitmentAge;

    /// @notice Maximum commitment age in seconds
    uint256 public maxCommitmentAge;

    /// @notice Reference to the price oracle for .LYX names
    IPriceOracle public prices;

    /// @notice Stores commitments with their timestamps
    mapping(bytes32 => uint256) public commitments;

    /// @notice Initializes the contract with LYX Registrar, Price oracle, and commitment age
    /// @param lyxRegistrar LYX Registrar contract address
    /// @param _prices PriceOracle contract address
    /// @param _minCommitmentAge Minimum commitment age in seconds
    /// @param _maxCommitmentAge Maximum commitment age in seconds
    constructor(
        LYXRegistrar lyxRegistrar,
        ReverseRegistrar reverseRegistrar,
        IPriceOracle _prices,
        uint256 _minCommitmentAge,
        uint256 _maxCommitmentAge
    ) {
        require(
            _maxCommitmentAge > _minCommitmentAge,
            "Max age must be greater than min age"
        );

        LYX_REGISTRAR = lyxRegistrar;
        REVERSE_REGISTRAR = reverseRegistrar;
        prices = _prices;
        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;
    }

    // Ownable functionality

    /// @notice Sets a new price oracle
    /// @param _prices The new PriceOracle contract address
    function setPriceOracle(IPriceOracle _prices) public onlyOwner {
        prices = _prices;
        emit NewPriceOracle(address(_prices));
    }

    /// @notice Adjusts the allowable age window for commitments
    /// @param _minCommitmentAge The minimum age in seconds
    /// @param _maxCommitmentAge The maximum age in seconds
    function setCommitmentAges(
        uint256 _minCommitmentAge,
        uint256 _maxCommitmentAge
    ) public onlyOwner {
        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;
    }

    /// @notice Allows the owner to withdraw all funds
    function withdraw() public onlyOwner {
        (bool success, bytes memory result) = msg.sender.call{
            value: address(this).balance
        }("");

        Address.verifyCallResult(success, result, "Withdraw failed");
    }

    // Public functionality

    /// @notice Returns the rental price for a .LYX name
    /// @dev Calculates the price based on the expiry and requested duration
    /// @param name The .LYX name to check
    /// @param duration Registration/renewal period in seconds
    /// @return price The price in wei
    function rentPrice(
        string memory name,
        uint256 duration
    ) public view override returns (IPriceOracle.Price memory price) {
        bytes32 hash = keccak256(bytes(name));
        return prices.price(name, LYX_REGISTRAR.nameExpires(hash), duration);
    }

    /// @notice Checks if a name meets the minimum requirements
    /// @param name The .LYX name to check
    /// @return True if the name is at least 3 characters long
    function valid(string memory name) public pure returns (bool) {
        return name.strlen() >= 3;
    }

    /// @notice Checks if a name is available for registration
    /// @param name The .LYX name to check
    /// @return True if the name is valid and available
    function available(string memory name) public view returns (bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && LYX_REGISTRAR.available(label);
    }

    /// @notice Generates a commitment hash for registering a name
    /// @dev Used for the basic commit-reveal scheme
    /// @param name The UNS name to commit
    /// @param owner_ The future owner of the name
    /// @param secret A secret to protect the commitment
    /// @return The commitment hash
    function makeCommitment(
        string memory name,
        address owner_,
        uint256 duration,
        bytes32 secret
    ) public pure returns (bytes32) {
        return
            makeCommitmentWithConfig(
                name,
                owner_,
                duration,
                secret,
                address(0),
                address(0),
                false
            );
    }

    /// @notice Generates a commitment hash for registering a name with configuration options
    /// @dev Used for commit-reveal with additional setup options
    /// @param name The UNS name to commit
    /// @param owner_ The future owner of the name
    /// @param secret A secret to protect the commitment
    /// @param resolver The resolver address for the name
    /// @param addr The address to point the name to
    /// @return The commitment hash
    function makeCommitmentWithConfig(
        string memory name,
        address owner_,
        uint256 duration,
        bytes32 secret,
        address resolver,
        address addr,
        bool reverseRecord
    ) public pure returns (bytes32) {
        bytes32 label = keccak256(bytes(name));
        if (resolver == address(0)) {
            require(
                addr == address(0),
                "No address resolution with no resolver"
            );
        }
        return
            keccak256(
                abi.encodePacked(
                    label,
                    owner_,
                    duration,
                    resolver,
                    addr,
                    secret,
                    reverseRecord
                )
            );
    }

    /// @notice Records a commitment in the contract
    /// @dev Stores the commitment and sets a timestamp
    /// @param commitment The commitment hash to store
    function commit(bytes32 commitment) public {
        require(
            // solhint-disable-next-line not-rely-on-time
            commitments[commitment] + maxCommitmentAge < block.timestamp,
            "Commitment too young"
        );

        // solhint-disable-next-line not-rely-on-time
        commitments[commitment] = block.timestamp;
    }

    /// @notice Registers a name using a prior commitment
    /// @dev This is an external function that wraps `registerWithConfig` for simple cases
    /// @param name The UNS name to register
    /// @param owner_ The future owner of the name
    /// @param duration Registration period in seconds
    /// @param secret The secret used to make the commitment
    function register(
        string calldata name,
        address owner_,
        uint256 duration,
        bytes32 secret
    ) external payable {
        registerWithConfig(
            name,
            owner_,
            duration,
            secret,
            address(0),
            address(0),
            false
        );
    }

    /// @notice Registers a name with configuration options using a prior commitment
    /// @dev Handles both simple and configured registrations
    /// @param name The UNS name to register
    /// @param owner_ The future owner of the name
    /// @param duration Registration period in seconds
    /// @param secret The secret used to make the commitment
    /// @param resolver The resolver to use
    /// @param addr The address to associate with the name
    function registerWithConfig(
        string memory name,
        address owner_,
        uint256 duration,
        bytes32 secret,
        address resolver,
        address addr,
        bool reverseRecord
    ) public payable {
        bytes32 commitment = makeCommitmentWithConfig(
            name,
            owner_,
            duration,
            secret,
            resolver,
            addr,
            reverseRecord
        );
        uint256 cost = _consumeCommitment(name, duration, commitment);

        uint256 expires;
        if (resolver != address(0)) {
            bytes[] memory resolverData = new bytes[](1);

            resolverData[0] = abi.encodeWithSignature(
                "setAddr(bytes32,address)",
                nodeLYX(keccak256(bytes(name))),
                addr
            );

            expires = LYX_REGISTRAR.register(
                keccak256(bytes(name)),
                owner_,
                "",
                resolver,
                resolverData,
                duration
            );
        } else {
            bytes[] memory resolverData = new bytes[](0);

            require(addr == address(0));
            expires = LYX_REGISTRAR.register(
                keccak256(bytes(name)),
                owner_,
                "",
                address(0),
                resolverData,
                duration
            );
        }

        emit NameRegistered(
            name,
            keccak256(bytes(name)),
            owner_,
            cost,
            expires
        );

        if (reverseRecord) {
            _setReverseRecord(name, resolver, msg.sender);
        }

        LYX_REGISTRAR.setDataForTokenId(
            keccak256(bytes(name)),
            LYX_REGISTRAR_TOKENID_NAME,
            bytes(name)
        );

        // Refund any extra payment
        if (msg.value > cost) {
            (bool success, bytes memory result) = msg.sender.call{
                value: msg.value - cost
            }("");

            Address.verifyCallResult(success, result, "Refund failed");
        }
    }

    /// @notice Supports interface method as per ERC-165
    /// @dev Used to check the supported interfaces
    /// @param interfaceID The interface identifier to check
    /// @return True if the interface is supported
    function supportsInterface(
        bytes4 interfaceID
    ) external pure returns (bool) {
        return interfaceID == type(ILYXFIFSController).interfaceId;
    }

    /// @dev Consumes a commitment to register or renew a name
    /// @param name The UNS name involved in the operation
    /// @param duration The period for which the name is registered or renewed
    /// @param commitment The commitment hash
    /// @return cost The cost in wei of the operation
    function _consumeCommitment(
        string memory name,
        uint256 duration,
        bytes32 commitment
    ) internal returns (uint256) {
        // Require a valid commitment
        require(
            // solhint-disable-next-line not-rely-on-time
            commitments[commitment] + minCommitmentAge <= block.timestamp,
            "Commitment too young"
        );

        // If the commitment is too old, or the name is registered, stop
        // solhint
        require(
            // solhint-disable-next-line not-rely-on-time
            commitments[commitment] + maxCommitmentAge > block.timestamp,
            "Commitment too old"
        );
        require(available(name), "Name is unavailable");

        delete (commitments[commitment]);

        IPriceOracle.Price memory price = rentPrice(name, duration);
        uint256 cost = price.base + price.premium;
        require(duration >= MIN_REGISTRATION_DURATION, "Duration too short");
        require(duration < MAX_REGISTRATION_DURATION, "Duration too long");
        require(msg.value >= cost, "Insufficient funds");

        return cost;
    }

    function _setReverseRecord(
        string memory name,
        address resolver,
        address owner_
    ) internal {
        bytes[] memory resolverData = new bytes[](1);
        resolverData[0] = abi.encodeWithSignature(
            "setName(bytes32,string)",
            nodeReverse(msg.sender),
            string.concat(name, ".lyx")
        );

        REVERSE_REGISTRAR.claimForAddrWithResolverData(
            msg.sender,
            owner_,
            resolver,
            resolverData
        );
    }

    /// @notice Computes the node hash for a given account's reverse records.
    /// @dev Returns the node hash for a specific address.
    /// @param labelHash The labelHash to compute the node hash for.
    /// @return The node hash.
    function nodeLYX(bytes32 labelHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(LYX_NAME_HASH, labelHash));
    }

    /// @notice Computes the node hash for a given account's reverse records.
    /// @dev Returns the node hash for a specific address.
    /// @param addr The address to compute the node hash for.
    /// @return The node hash.
    function nodeReverse(address addr) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(ADDR_REVERSE_NODE, _sha3HexAddress(addr))
            );
    }

    /// @dev Computes the SHA3 hash of the lower-case hexadecimal representation of an Ethereum address.
    /// @param addr The address to hash.
    /// @return ret The SHA3 hash of the lower-case hexadecimal encoding of the input address.
    function _sha3HexAddress(address addr) internal pure returns (bytes32 ret) {
        assembly {
            for {
                let i := 40
            } gt(i, 0) {

            } {
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }

            ret := keccak256(0, 40)
        }
    }
}
