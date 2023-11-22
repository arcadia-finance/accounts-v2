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
 * @dev Each different oracle implementation (Chainlink, Pyth, Uniswap V3 TWAPs...) should have its own Oracle Module.
 * The Oracle Modules will:
 *  - Return the oracle rate in a standardized format with 18 decimals precision.
 *  - Decommission non-functioning oracles.
 */
abstract contract OracleModule is Owned {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the Registry.
    address public immutable REGISTRY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map oracle identifier => Asset pair.
    mapping(uint256 => AssetPair) public assetPair;

    struct AssetPair {
        // Label for the base asset.
        bytes16 baseAsset;
        // Label for the quote asset.
        bytes16 quoteAsset;
    }
    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error InactiveOracle();
    error OracleAlreadyAdded();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The contract address of the Registry.
     */
    constructor(address registry_) Owned(msg.sender) {
        REGISTRY = registry_;
    }

    /*///////////////////////////////////////////////////////////////
                        ORACLE INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the state of an oracle.
     * @param oracleId The identifier of the oracle to be checked.
     * @return oracleIsActive Boolean indicating if the oracle is active or not.
     */
    function isActive(uint256 oracleId) external view virtual returns (bool);

    /*///////////////////////////////////////////////////////////////
                          ORACLE MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets an oracle to inactive if it is not properly functioning.
     * @param oracleId The identifier of the oracle to be checked.
     * @return oracleIsActive Boolean indicating if the oracle is still in use.
     * @dev An inactive oracle will revert.
     * @dev Anyone can call this function as part of an oracle failsafe mechanism.
     * @dev If the oracle becomes functionally again (all checks pass), anyone can activate the oracle again.
     */
    function decommissionOracle(uint256 oracleId) external virtual returns (bool);

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the rate of the BaseAsset in units of QuoteAsset (BaseAsset/QuoteAsset).
     * @param oracleId The identifier of the oracle.
     * @return oracleRate The rate of the BaseAsset in units of QuoteAsset, with 18 decimals precision.
     * @dev The oracle rate expresses how much units of the QuoteAsset are required
     * to buy 1 unit of the BaseAsset, with 18 decimals precision.
     * Example: If you have an oracle (WBTC/USDC).
     *  - The BaseAsset is Wrapped Bitcoin (WBTC), which has 8 decimals.
     *  - The QuoteAsset is USDC, which has 6 decimals.
     *  - Assume an exchange rate from Bitcoin to USD of $30 000.
     *  -> You need $30 000 (or 30 000 * 10^6 USDC) to buy 1 Bitcoin (or 1 * 10^8 WBTC).
     *  -> You need 300 units of USDC to buy one unit of WBT.
     * Since we use 18 decimals precision, the oracleRate will be 300 * 10^18.
     */
    function getRate(uint256 oracleId) external view virtual returns (uint256);
}
