/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

/// @notice Abstract contract containing all the events emitted by the protocol.
abstract contract Events {
    /*//////////////////////////////////////////////////////////////////////////
                                      ERC-721
    //////////////////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////////////////
                                      ERC-1155
    //////////////////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////////////////
                                      PROXY
    //////////////////////////////////////////////////////////////////////////*/

    event Upgraded(address indexed implementation);

    /*//////////////////////////////////////////////////////////////////////////
                                     FACTORY
    //////////////////////////////////////////////////////////////////////////*/

    event AccountUpgraded(address indexed accountAddress, uint16 oldVersion, uint16 indexed newVersion);
    event AccountVersionAdded(
        uint16 indexed version, address indexed registry, address indexed logic, bytes32 versionRoot
    );
    event AccountVersionBlocked(uint16 version);

    /*//////////////////////////////////////////////////////////////////////////
                                      ACCOUNT
    //////////////////////////////////////////////////////////////////////////*/

    event AssetManagerSet(address indexed owner, address indexed assetManager, bool value);
    event BaseCurrencySet(address baseCurrency);
    event TrustedMarginAccountChanged(address indexed protocol, address indexed liquidator);

    /*//////////////////////////////////////////////////////////////////////////
                                BASE GUARDIAN
    //////////////////////////////////////////////////////////////////////////*/

    event GuardianChanged(address indexed oldGuardian, address indexed newGuardian);

    /*//////////////////////////////////////////////////////////////////////////
                                FACTORY GUARDIAN
    //////////////////////////////////////////////////////////////////////////*/

    event PauseUpdate(bool createPauseUpdate, bool liquidatePauseUpdate);

    /*//////////////////////////////////////////////////////////////////////////
                                    ORACLEHUB
    //////////////////////////////////////////////////////////////////////////*/

    event OracleAdded(address indexed oracle, address indexed quoteAsset, bytes16 baseAsset);
    event OracleDecommissioned(address indexed oracle, bool isActive);

    /*//////////////////////////////////////////////////////////////////////////
                                  MAIN REGISTRY
    //////////////////////////////////////////////////////////////////////////*/

    event AllowedActionSet(address indexed action, bool allowed);
    event AssetAdded(address indexed assetAddress, address indexed pricingModule, uint8 assetType);
    event BaseCurrencyAdded(address indexed assetAddress, uint8 indexed baseCurrencyId, bytes8 label);
    event PricingModuleAdded(address pricingModule);

    /*//////////////////////////////////////////////////////////////////////////
                                PRICING MODULE
    //////////////////////////////////////////////////////////////////////////*/

    event RiskManagerUpdated(address riskManager);
    event RiskVariablesSet(
        address indexed asset, uint8 indexed baseCurrencyId, uint16 collateralFactor, uint16 liquidationFactor
    );
    event MaxExposureSet(address indexed asset, uint128 maxExposure);

    /*//////////////////////////////////////////////////////////////////////////
                            DERIVED PRICING MODULE
    //////////////////////////////////////////////////////////////////////////*/

    event MaxUsdExposureProtocolSet(uint256 maxExposure);
}
