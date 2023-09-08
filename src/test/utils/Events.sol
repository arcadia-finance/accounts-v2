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
                                      PROXY
    //////////////////////////////////////////////////////////////////////////*/

    event Upgraded(address indexed implementation);

    /*//////////////////////////////////////////////////////////////////////////
                                     FACTORY
    //////////////////////////////////////////////////////////////////////////*/

    event AccountUpgraded(address indexed accountAddress, uint16 oldVersion, uint16 indexed newVersion);

    /*//////////////////////////////////////////////////////////////////////////
                                      ACCOUNT
    //////////////////////////////////////////////////////////////////////////*/

    event TrustedMarginAccountChanged(address indexed protocol, address indexed liquidator);
    event BaseCurrencySet(address baseCurrency);

    /*//////////////////////////////////////////////////////////////////////////
                                    ORACLEHUB
    //////////////////////////////////////////////////////////////////////////*/

    event OracleAdded(address indexed oracle, address indexed quoteAsset, bytes16 baseAsset);
    event OracleDecommissioned(address indexed oracle, bool isActive);

    /*//////////////////////////////////////////////////////////////////////////
                                PRICING MODULE
    //////////////////////////////////////////////////////////////////////////*/

    event RiskManagerUpdated(address riskManager);
    event RiskVariablesSet(
        address indexed asset, uint8 indexed baseCurrencyId, uint16 collateralFactor, uint16 liquidationFactor
    );
    event MaxExposureSet(address indexed asset, uint128 maxExposure);
}
