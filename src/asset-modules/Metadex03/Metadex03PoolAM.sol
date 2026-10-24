/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

import { AerodromePoolAM } from "../Aerodrome-Finance/AerodromePoolAM.sol";
import { IMetadex03Pool } from "./interfaces/IMetadex03Pool.sol";
import { IMetadex03PoolFactory } from "./interfaces/IMetadex03PoolFactory.sol";
import { Unused } from "../../libraries/Unused.sol";

/**
 * @title Asset Module for Metadex03 pools
 * @author Pragma Labs
 * @notice The pricing logic and basic information for Metadex03 pools.
 */
contract Metadex03PoolAM is AerodromePoolAM {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The Metadex03 PoolFactory of the stable pools.
    IMetadex03PoolFactory public immutable STABLE_POOL_FACTORY;

    // The Metadex03 PoolFactory of the volatile pools.
    IMetadex03PoolFactory public immutable VOLATILE_POOL_FACTORY;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error InvalidPoolType();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param owner_ The address of the Owner.
     * @param registry_ The address of the Registry.
     * @param stablePoolFactory The contract address of the Metadex03 PoolFactory of the stable pools.
     * @param volatilePoolFactory The contract address of the Metadex03 PoolFactory of the volatile pools.
     */
    constructor(address owner_, address registry_, address stablePoolFactory, address volatilePoolFactory)
        AerodromePoolAM(owner_, registry_, Unused.IMMUTABLE)
    {
        STABLE_POOL_FACTORY = IMetadex03PoolFactory(stablePoolFactory);
        VOLATILE_POOL_FACTORY = IMetadex03PoolFactory(volatilePoolFactory);
    }

    /* ///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc AerodromePoolAM
     */
    function _isPool(address pool) internal view override returns (bool isPool_) {
        isPool_ = STABLE_POOL_FACTORY.isPool(pool) || VOLATILE_POOL_FACTORY.isPool(pool);
    }

    /**
     * @inheritdoc AerodromePoolAM
     */
    function _isStablePool(address pool) internal view override returns (bool isStable) {
        bytes32 poolType = IMetadex03Pool(pool).POOL_TYPE();
        if (poolType == "V2_STABLE") return true;
        if (poolType != "V2_VOLATILE") revert InvalidPoolType();
    }
}
