/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

library AccountErrors {
    error AccountInAuction();
    error AccountNotLiquidatable();
    error AccountUnhealthy();
    error AlreadyInitialized();
    error CreditorAlreadySet();
    error CreditorNotSet();
    error CoolDownPeriodNotPassed();
    error InvalidAccountVersion();
    error InvalidERC20Id();
    error InvalidERC721Amount();
    error InvalidRecipient();
    error InvalidRegistry();
    error NoFallback();
    error NoReentry();
    error NonZeroOpenPosition();
    error NumeraireNotFound();
    error OnlyFactory();
    error OnlyCreditor();
    error OnlyLiquidator();
    error OnlyOwner();
    error TooManyAssets();
    error UnknownAsset();
    error UnknownAssetType();
}

library FactoryErrors {
    error AccountVersionBlocked();
    error FactoryMismatch();
    error InvalidAccountVersion();
    error InvalidRecipient();
    error InvalidUpgrade();
    error ImplIsZero();
    error OnlyAccount();
    error OnlyAccountOwner();
    error UnsafeRecipient();
    error VersionMismatch();
    error VersionRootIsZero();
}

library GuardianErrors {
    // Thrown when the cool-down period has not yet passed.
    error CoolDownPeriodNotPassed();
    // Thrown when the functionality is paused.
    error FunctionIsPaused();
    // Thrown when the caller is not the Guardian.
    error OnlyGuardian();
}

library RegistryErrors {
    error AssetModNotUnique();
    error AssetAlreadyInRegistry();
    error AssetNotAllowed();
    error SequencerDown();
    error LengthMismatch();
    error MaxRecursiveCallsReached();
    error Min1Oracle();
    error OnlyAccount();
    error OnlyAssetModule();
    error OnlyOracleModule();
    error OracleModNotUnique();
    error OracleNotReverting();
    error OracleReverting();
    error Unauthorized();
}
