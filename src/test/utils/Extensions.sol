/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { MainRegistry_UsdOnly } from "../../MainRegistry_UsdOnly.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { AccountV1 } from "../../AccountV1.sol";

contract MainRegistryExtension is MainRegistry_UsdOnly {
    using FixedPointMathLib for uint256;

    constructor(address factory_) MainRegistry_UsdOnly(factory_) { }

    function setAssetType(address asset, uint96 assetType) public {
        assetToAssetInformation[asset].assetType = assetType;
    }
}

contract AccountExtension is AccountV1 {
    constructor() AccountV1() { }

    function getLocked() external view returns (uint256 locked_) {
        locked_ = locked;
    }

    function setLocked(uint256 locked_) external {
        locked = locked_;
    }

    function getLengths() external view returns (uint256, uint256, uint256, uint256) {
        return (erc20Stored.length, erc721Stored.length, erc721TokenIds.length, erc1155Stored.length);
    }

    function setTrustedCreditor(address trustedCreditor_) public {
        trustedCreditor = trustedCreditor_;
    }

    function setIsTrustedCreditorSet(bool set) public {
        isTrustedCreditorSet = set;
    }

    function setFixedLiquidationCost(uint96 fixedLiquidationCost_) public {
        fixedLiquidationCost = fixedLiquidationCost_;
    }

    function setOwner(address newOwner) public {
        owner = newOwner;
    }

    function setRegistry(address registry_) public {
        registry = registry_;
    }
}
