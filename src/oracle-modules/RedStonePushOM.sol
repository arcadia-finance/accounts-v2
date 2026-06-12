/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

import { ChainlinkOM } from "./ChainlinkOM.sol";

/**
 * @title Redstone Push Oracle Module
 * @author Pragma Labs
 * @notice Oracle Module for Redstone Push Oracles.
 */
contract RedStonePushOM is ChainlinkOM {
    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param owner_ The address of the Owner.
     * @param registry_ The contract address of the Registry.
     */
    constructor(address owner_, address registry_) ChainlinkOM(owner_, registry_) { }
}
