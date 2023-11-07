/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Owned } from "../../lib/solmate/src/auth/Owned.sol";

/**
 * @title Abstract Oracle Module
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of an Oracle Module.
 */
abstract contract OracleModule is Owned {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the OracleHub.
    address public immutable ORACLE_HUB;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map oracle => flag.
    mapping(address => bool) public inOracleModule;

    // Map identifier => oracle information.
    mapping(uint256 => AssetPair) public assetPair;

    struct AssetPair {
        // Label for the base asset.
        bytes16 baseAsset;
        // Label for the quote asset.
        bytes16 quoteAsset;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Only the Main Registry can call functions with this modifier.
     */
    modifier onlyMainReg() {
        require(msg.sender == ORACLE_HUB, "APM: ONLY_MAIN_REGISTRY");
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param oracleHub_ The contract address of the OracleHub.
     */
    constructor(address oracleHub_) Owned(msg.sender) {
        ORACLE_HUB = oracleHub_;
    }

    /*///////////////////////////////////////////////////////////////
                        ORACLE INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the state of an oracle.
     * @param oracleId The identifier of the oracle to be checked.
     * @return boolean indicating if the oracle is active or not.
     */
    function isActive(uint256 oracleId) external view virtual returns (bool);

    /*///////////////////////////////////////////////////////////////
                          ORACLE MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets an oracle to inactive if it is not properly functioning.
     * @param oracleId The identifier of the oracle to be checked.
     * @return success Boolean indicating if the oracle is still in use.
     * @dev An inactive oracle will always return a rate of 0.
     * @dev Anyone can call this function as part of an oracle failsafe mechanism.
     * An oracles can only be decommissioned if it is not performing as intended:
     * - A call to the oracle reverts.
     * - The oracle returns the minimum value.
     * - The oracle didn't update for over a week.
     * @dev If the oracle would becomes functionally again (all checks pass), anyone can activate the oracle again.
     */
    function decommissionOracle(uint256 oracleId) external virtual returns (bool);

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the rate of two assets.
     * @param oracleId The identifier of the oracle to be checked.
     * @return oracleRate The value of the asset denominated in USD, with 18 Decimals precision.
     * @dev The oracle rate reflects how much of the QuoteAsset is required to buy 1 unit of the BaseAsset
     */
    function getRate(uint256 oracleId) external view virtual returns (uint256);
}
