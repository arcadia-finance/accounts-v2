/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { MainRegistry } from "../../MainRegistry.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Vault } from "../../Vault.sol";

contract MainRegistryExtension is MainRegistry {
    using FixedPointMathLib for uint256;

    constructor(address factory_) MainRegistry(factory_) { }

    function setAssetType(address asset, uint96 assetType) public {
        assetToAssetInformation[asset].assetType = assetType;
    }
}

contract VaultExtension is Vault {
    constructor(address mainReg_, uint16 vaultVersion_) Vault() {
        registry = mainReg_;
        vaultVersion = vaultVersion_;
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

    function setVaultVersion(uint16 version) public {
        vaultVersion = version;
    }

    function setFixedLiquidationCost(uint96 fixedLiquidationCost_) public {
        fixedLiquidationCost = fixedLiquidationCost_;
    }

    function setOwner(address newOwner) public {
        owner = newOwner;
    }
}
