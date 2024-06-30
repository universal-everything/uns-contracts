// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IABIResolver} from "../resolvers/profiles/IABIResolver.sol";
import {IAddressResolver} from "../resolvers/profiles/IAddressResolver.sol";
import {IAddrResolver} from "../resolvers/profiles/IAddrResolver.sol";
import {IContentHashResolver} from "../resolvers/profiles/IContentHashResolver.sol";
import {IDNSRecordResolver} from "../resolvers/profiles/IDNSRecordResolver.sol";
import {IDNSZoneResolver} from "../resolvers/profiles/IDNSZoneResolver.sol";
import {IERC725YBasedResolver} from "../resolvers/profiles/IERC725YBasedResolver.sol";
import {IExtendedDNSResolver} from "../resolvers/profiles/IExtendedDNSResolver.sol";
import {IExtendedResolver} from "../resolvers/profiles/IExtendedResolver.sol";
import {IInterfaceResolver} from "../resolvers/profiles/IInterfaceResolver.sol";
import {INameResolver} from "../resolvers/profiles/INameResolver.sol";
import {IPubkeyResolver} from "../resolvers/profiles/IPubkeyResolver.sol";
import {ITextResolver} from "../resolvers/profiles/ITextResolver.sol";
import {IVersionableResolver} from "../resolvers/profiles/IVersionableResolver.sol";
import {Multicallable} from "../resolvers/Multicallable.sol";
import {IUNSRegistry} from "../UNSRegistry/IUNSRegistry.sol";
import {NameEncoder} from "./NameEncoder.sol";

contract ReadOnlyResolver is Multicallable {
    IUNSRegistry private immutable _registry;

    constructor(IUNSRegistry registry) {
        _registry = registry;
    }

    function nameWithRecordInfo(
        bytes32 node
    ) external view returns (string memory, address, address, address) {
        address reverseResolverAddress = _registry.resolver(node);
        if (reverseResolverAddress == address(0)) {
            return ("", address(0), address(0), address(0));
        }
        string memory name_ = INameResolver(reverseResolverAddress).name(node);
        if (bytes(name_).length == 0)
            return ("", reverseResolverAddress, address(0), address(0));
        (, bytes32 nameHash) = NameEncoder.dnsEncodeName(name_);
        address nameResolverAddress = _registry.resolver(nameHash);
        if (nameResolverAddress == address(0)) {
            return (name_, reverseResolverAddress, address(0), address(0));
        }
        address resolvedAddress = address(
            bytes20(IAddressResolver(nameResolverAddress).addr(nameHash, 60))
        );

        return (
            name_,
            reverseResolverAddress,
            nameResolverAddress,
            resolvedAddress
        );
    }

    function multicallWithResolver(
        bytes32 nodehash,
        bytes[] calldata data
    ) external returns (address resolver, bytes[] memory results) {
        resolver = _registry.resolver(nodehash);
        if (resolver == address(0)) return (address(0), new bytes[](0));
        return (resolver, _multicall(bytes32(0), data));
    }

    function ABI(
        bytes32 node,
        uint256 contentTypes
    ) external view returns (uint256, bytes memory) {
        address resolverAddress = _registry.resolver(node);
        if (resolverAddress == address(0)) return (0, "");
        return IABIResolver(resolverAddress).ABI(node, contentTypes);
    }

    function addr(
        bytes32 node,
        uint256 coinType
    ) external view returns (bytes memory) {
        address resolverAddress = _registry.resolver(node);
        if (resolverAddress == address(0)) return "";
        return IAddressResolver(resolverAddress).addr(node, coinType);
    }

    function addr(bytes32 node) external view returns (address payable) {
        address resolverAddress = _registry.resolver(node);
        if (resolverAddress == address(0)) return payable(address(0));
        return IAddrResolver(resolverAddress).addr(node);
    }

    function contenthash(bytes32 node) external view returns (bytes memory) {
        address resolverAddress = _registry.resolver(node);
        if (resolverAddress == address(0)) return "";
        return IContentHashResolver(resolverAddress).contenthash(node);
    }

    function dnsRecord(
        bytes32 node,
        bytes32 name_,
        uint16 resource
    ) external view returns (bytes memory) {
        address resolverAddress = _registry.resolver(node);
        if (resolverAddress == address(0)) return "";
        return
            IDNSRecordResolver(resolverAddress).dnsRecord(
                node,
                name_,
                resource
            );
    }

    function zonehash(bytes32 node) external view returns (bytes memory) {
        address resolverAddress = _registry.resolver(node);
        if (resolverAddress == address(0)) return "";
        return IDNSZoneResolver(resolverAddress).zonehash(node);
    }

    function getData(
        bytes32 nameHash,
        bytes32 dataKey
    ) external view returns (bytes memory) {
        address resolverAddress = _registry.resolver(nameHash);
        if (resolverAddress == address(0)) return "";
        return
            IERC725YBasedResolver(resolverAddress).getData(nameHash, dataKey);
    }

    function getDataBatch(
        bytes32 nameHash,
        bytes32[] memory dataKeys
    ) external view returns (bytes[] memory) {
        address resolverAddress = _registry.resolver(nameHash);
        if (resolverAddress == address(0)) return new bytes[](0);
        return
            IERC725YBasedResolver(resolverAddress).getDataBatch(
                nameHash,
                dataKeys
            );
    }

    function resolve(
        bytes memory name_,
        bytes memory data,
        bytes memory context
    ) external view returns (bytes memory) {
        address resolverAddress = _registry.resolver(keccak256(name_));
        if (resolverAddress == address(0)) return "";
        return
            IExtendedDNSResolver(resolverAddress).resolve(name_, data, context);
    }

    function resolve(
        bytes memory name_,
        bytes memory data
    ) external view returns (bytes memory) {
        address resolverAddress = _registry.resolver(keccak256(name_));
        if (resolverAddress == address(0)) return "";
        return IExtendedResolver(resolverAddress).resolve(name_, data);
    }

    function interfaceImplementer(
        bytes32 node,
        bytes4 interfaceID
    ) external view returns (address) {
        address resolverAddress = _registry.resolver(node);
        if (resolverAddress == address(0)) return address(0);
        return
            IInterfaceResolver(resolverAddress).interfaceImplementer(
                node,
                interfaceID
            );
    }

    function name(bytes32 node) external view returns (string memory) {
        address resolverAddress = _registry.resolver(node);
        if (resolverAddress == address(0)) return "";
        return INameResolver(resolverAddress).name(node);
    }

    function pubkey(bytes32 node) external view returns (bytes32 x, bytes32 y) {
        address resolverAddress = _registry.resolver(node);
        if (resolverAddress == address(0)) return (bytes32(0), bytes32(0));
        return IPubkeyResolver(resolverAddress).pubkey(node);
    }

    function text(
        bytes32 node,
        string calldata key
    ) external view returns (string memory) {
        address resolverAddress = _registry.resolver(node);
        if (resolverAddress == address(0)) return "";
        return ITextResolver(resolverAddress).text(node, key);
    }

    function recordVersions(bytes32 node) external view returns (uint64) {
        address resolverAddress = _registry.resolver(node);
        if (resolverAddress == address(0)) return 0;
        return IVersionableResolver(resolverAddress).recordVersions(node);
    }
}
