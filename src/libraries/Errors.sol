/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

library AccountErrors {
    error AccountNotLiquidatable();
    error AccountUnhealthy();
    error ActionNotAllowed();
    error AlreadyInitialized();
    error BaseCurrencyNotFound();
    error CreditorAlreadySet();
    error CreditorNotSet();
    error InvalidAccountVersion();
    error InvalidERC20Id();
    error InvalidERC721Amount();
    error InvalidRecipient();
    error InvalidRegistry();
    error NoFallback();
    error NoReentry();
    error NonZeroOpenPosition();
    error OnlyFactory();
    error OnlyLiquidator();
    error OnlyOwner();
    error TooManyAssets();
    error UnknownAsset();
    error UnknownAssetType();
    error AccountInAuction();
}

library FactoryErrors {
    error AccountVersionBlocked();
    error InvalidAccountVersion();
    error InvalidUpgrade();
    error ImplIsZero();
    error OnlyAccountOwner();
    error VersionMismatch();
    error VersionRootIsZero();
}

library RegistryErrors {
    error AssetMod_Not_Unique();
    error Asset_Already_In_Registry();
    error Length_Mismatch();
    error Min_1_Oracle();
    error Only_Account();
    error Only_AssetModule();
    error Only_OracleModule();
    error OracleMod_Not_Unique();
    error Unauthorized();
}
