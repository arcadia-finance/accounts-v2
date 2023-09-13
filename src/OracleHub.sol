/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { IChainLinkData } from "./interfaces/IChainLinkData.sol";
import { IOraclesHub } from "./pricing-modules/interfaces/IOraclesHub.sol";
import { StringHelpers } from "./utils/StringHelpers.sol";
import { FixedPointMathLib } from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Owned } from "../lib/solmate/src/auth/Owned.sol";

/**
 * @title Oracle Hub
 * @author Pragma Labs
 * @notice The Oracle Hub stores the information of the Price Oracles and calculates rates of assets in USD.
 * @dev Terminology:
 * - oracles are named as BaseAsset/QuoteAsset: The oracle rate reflects how much of the QuoteAsset is required to buy 1 unit of the BaseAsset
 */
contract OracleHub is Owned, IOraclesHub {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map oracle => flag.
    mapping(address => bool) public inOracleHub;
    // Map oracle => assetInformation.
    mapping(address => OracleInformation) public oracleToOracleInformation;

    // Struct with additional information for a specific oracle.
    struct OracleInformation {
        bool isActive; // Flag indicating if the oracle is active or decommissioned.
        uint64 oracleUnit; // The unit of the oracle, equal to 10^decimalsOracle.
        address oracle; // The contract address of the oracle.
        address baseAssetAddress; // The contract address of the base asset.
        bytes16 baseAsset; // Human readable label for the base asset.
        bytes16 quoteAsset; // Human readable label for the quote asset.
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event OracleAdded(address indexed oracle, address indexed quoteAsset, bytes16 baseAsset);
    event OracleDecommissioned(address indexed oracle, bool isActive);

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() Owned(msg.sender) { }

    /*///////////////////////////////////////////////////////////////
                          ORACLE MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new oracle to the Oracle Hub.
     * @param oracleInformation A Struct with information about the Oracle:
     * - isActive: Flag indicating if the oracle is active or decommissioned.
     * - oracleUnit: The unit of the oracle, equal to 10^decimalsOracle.
     * - oracle: The contract address of the oracle.
     * - baseAssetAddress: The contract address of the base asset.
     * - baseAsset: Human readable label for the base asset.
     * - quoteAsset: Human readable label for the quote asset.
     * @dev It is not possible to overwrite the information of an existing Oracle in the Oracle Hub.
     * @dev Oracles can't have more than 18 decimals.
     */
    function addOracle(OracleInformation calldata oracleInformation) external onlyOwner {
        address oracle = oracleInformation.oracle;
        require(!inOracleHub[oracle], "OH_AO: Oracle not unique");
        require(oracleInformation.oracleUnit <= 1_000_000_000_000_000_000, "OH_AO: Maximal 18 decimals");
        inOracleHub[oracle] = true;
        oracleToOracleInformation[oracle] = oracleInformation;

        emit OracleAdded(oracle, oracleInformation.baseAssetAddress, oracleInformation.quoteAsset);
    }

    /**
     * @notice Verifies whether a sequence of oracles complies with a predetermined set of criteria.
     * @param oracles Array of contract addresses of oracles.
     * @param asset The contract address of the base-asset.
     * @dev Function will do nothing if all checks pass, but reverts if at least one check fails.
     * The following checks are performed:
     * - The oracle must be previously added to the Oracle-Hub and must still be active.
     * - The first oracle in the series must have asset as base-asset
     * - The quote-asset of all oracles must be equal to the base-asset of the next oracle (except for the last oracle in the series).
     * - The last oracle in the series must have USD as quote-asset.
     */
    function checkOracleSequence(address[] calldata oracles, address asset) external view {
        uint256 oracleAddressesLength = oracles.length;
        require(oracleAddressesLength > 0, "OH_COS: Min 1 Oracle");
        require(oracleAddressesLength <= 3, "OH_COS: Max 3 Oracles");
        address oracle;
        for (uint256 i; i < oracleAddressesLength;) {
            oracle = oracles[i];
            require(oracleToOracleInformation[oracle].isActive, "OH_COS: Oracle not active");
            if (i == 0) {
                require(asset == oracleToOracleInformation[oracle].baseAssetAddress, "OH_COS: No Match First bAsset");
            } else {
                require(
                    oracleToOracleInformation[oracles[i - 1]].quoteAsset == oracleToOracleInformation[oracle].baseAsset,
                    "OH_COS: No Match bAsset and qAsset"
                );
            }
            if (i == oracleAddressesLength - 1) {
                require(oracleToOracleInformation[oracle].quoteAsset == "USD", "OH_COS: Last qAsset not USD");
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Sets an oracle to inactive if it is not properly functioning.
     * @param oracle The contract address of the oracle to be checked.
     * @return success Boolean indicating if the oracle is still in use.
     * @dev An inactive oracle will always return a rate of 0.
     * @dev Anyone can call this function as part of an oracle failsafe mechanism.
     * An oracles can only be decommissioned if it is not performing as intended:
     * - A call to the oracle reverts.
     * - The oracle returns the minimum value.
     * - The oracle didn't update for over a week.
     * @dev If the oracle would becomes functionally again (all checks pass), anyone can activate the oracle again.
     */
    function decommissionOracle(address oracle) external returns (bool) {
        require(inOracleHub[oracle], "OH_DO: Oracle not in Hub");

        bool oracleIsInUse = true;

        try IChainLinkData(oracle).latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
        {
            int192 min = IChainLinkData(IChainLinkData(oracle).aggregator()).minAnswer();
            if (answer <= min) {
                oracleIsInUse = false;
            } else if (updatedAt <= block.timestamp - 1 weeks) {
                oracleIsInUse = false;
            }
        } catch {
            oracleIsInUse = false;
        }

        oracleToOracleInformation[oracle].isActive = oracleIsInUse;

        emit OracleDecommissioned(oracle, oracleIsInUse);

        return oracleIsInUse;
    }

    /**
     * @notice Returns the state of an oracle.
     * @param oracle The contract address of the oracle to be checked.
     * @return boolean indicating if the oracle is active or not.
     */
    function isActive(address oracle) external view returns (bool) {
        return oracleToOracleInformation[oracle].isActive;
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the rate of a certain asset, denominated in USD.
     * @param oracles Array of contract addresses of oracles.
     * @return rate The rate of the asset denominated in USD, with 18 Decimals precision.
     * @dev The Function will loop over all oracles-addresses and find the total rate of the asset by
     * multiplying the intermediate exchange-rates (max 3) with each other. Oracles can have any Decimals precision smaller than 18.
     * All intermediate rates are calculated with a precision of 18 decimals and rounded down.
     * Function will overflow if any of the intermediate or the final rate overflows.
     * Example of 3 oracles with R1 the first rate with D1 decimals and R2 the second rate with D2 decimals R3...
     * - First intermediate rate will overflow when R1 * 10**18 > MAXUINT256.
     * - Second rate will overflow when R1 * R2 * 10**(18 - D1) > MAXUINT256.
     * - Third and final rate will overflow when R1 * R2 * R3 * 10**(18 - D1 - D2) > MAXUINT256.
     */
    function getRateInUsd(address[] memory oracles) external view returns (uint256 rate) {
        rate = FixedPointMathLib.WAD; // Scalar 1 with 18 decimals (The internal precision).
        int256 tempRate;
        uint256 oraclesLength = oracles.length;
        address oracle;

        for (uint256 i; i < oraclesLength;) {
            oracle = oracles[i];

            // If the oracle is not active anymore (decommissioned), return value 0 -> assets do not count as collateral anymore.
            if (!oracleToOracleInformation[oracle].isActive) return (0);

            (, tempRate,,,) = IChainLinkData(oracle).latestRoundData();
            require(tempRate >= 0, "OH_GR: Negative Rate");

            rate = rate.mulDivDown(uint256(tempRate), oracleToOracleInformation[oracle].oracleUnit);

            unchecked {
                ++i;
            }
        }
    }
}
