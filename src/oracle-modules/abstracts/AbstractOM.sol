/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Owned } from "../../../lib/solmate/src/auth/Owned.sol";

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
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the rate of the BaseAsset in units of QuoteAsset (BaseAsset/QuoteAsset).
     * @param oracleId The identifier of the oracle.
     * @return oracleRate The rate of the BaseAsset in units of QuoteAsset, with 18 decimals precision.
     * @dev The oracle rate expresses how much tokens of the QuoteAsset are required
     * to buy 1 token of the BaseAsset, with 18 decimals precision.
     * Example: If you have an oracle (WBTC/USDC) and assume an exchange rate from Bitcoin to USD of $30 000.
     *  -> You need 30 000 tokens of USDC to buy one token of WBTC.
     *  -> Since we use 18 decimals precision, the oracleRate will be 30 000 * 10**18.
     */
    function getRate(uint256 oracleId) external view virtual returns (uint256);
}
