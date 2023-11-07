/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { OracleModule } from "./AbstractOracleModule.sol";
import { IChainLinkData } from "../interfaces/IChainLinkData.sol";
import { IOracleHub } from "./interfaces/IOracleHub.sol";

/**
 * @title Abstract Oracle Module
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of an Oracle Module.
 */
contract ChainLinkOracleModule is OracleModule {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map identifier => oracle information.
    mapping(uint256 => OracleInformation) internal oracleInformation;

    struct OracleInformation {
        // Flag indicating if the oracle is active or decommissioned.
        bool isActive;
        // The correction with which the oracle-rate has to be multiplied to get a precision of 18 decimals.
        uint64 unitCorrection;
        // The contract address of the oracle.
        address oracle;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param oracleHub_ The contract address of the OracleHub.
     */
    constructor(address oracleHub_) OracleModule(oracleHub_) { }

    /*///////////////////////////////////////////////////////////////
                        ORACLE INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the state of an oracle.
     * @param oracleId The identifier of the oracle to be checked.
     * @return boolean indicating if the oracle is active or not.
     */
    function isActive(uint256 oracleId) external view override returns (bool) {
        return oracleInformation[oracleId].isActive;
    }

    /*///////////////////////////////////////////////////////////////
                          ORACLE MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function addAsset(address oracle, bytes16 baseAsset, bytes16 quoteAsset) external onlyOwner {
        uint256 decimals = IChainLinkData(oracle).decimals();
        require(decimals <= 18, "OH_AO: Maximal 18 decimals");

        uint256 oracleId = IOracleHub(ORACLE_HUB).addOracle();

        assetPair[oracleId] = AssetPair({ baseAsset: baseAsset, quoteAsset: quoteAsset });
        oracleInformation[oracleId] =
            OracleInformation({ isActive: true, unitCorrection: uint64(10 ** (18 - decimals)), oracle: oracle });
    }

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
    function decommissionOracle(uint256 oracleId) external override returns (bool) {
        address oracle = oracleInformation[oracleId].oracle;

        bool oracleIsInUse = true;

        try IChainLinkData(oracle).latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
        {
            if (answer <= IChainLinkData(IChainLinkData(oracle).aggregator()).minAnswer()) {
                oracleIsInUse = false;
            } else if (answer >= IChainLinkData(IChainLinkData(oracle).aggregator()).maxAnswer()) {
                oracleIsInUse = false;
            } else if (updatedAt <= block.timestamp - 1 weeks) {
                oracleIsInUse = false;
            }
        } catch {
            oracleIsInUse = false;
        }

        oracleInformation[oracleId].isActive = oracleIsInUse;

        return oracleIsInUse;
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the rate of two assets.
     * @param oracleId The identifier of the oracle to be checked.
     * @return oracleRate The current rate, with 18 Decimals precision.
     * @dev The oracle rate reflects how much of the QuoteAsset is required to buy 1 unit of the BaseAsset.
     */
    function getRate(uint256 oracleId) external view override returns (uint256 oracleRate) {
        OracleInformation memory oracleInformation_ = oracleInformation[oracleId];
        // If the oracle is not active anymore (decommissioned), return value 0 -> assets do not count as collateral anymore.
        if (!oracleInformation_.isActive) return (0);

        (, int256 tempRate,,,) = IChainLinkData(oracleInformation_.oracle).latestRoundData();
        require(tempRate >= 0, "OH_GR: Negative Rate");

        unchecked {
            oracleRate = uint256(tempRate) * oracleInformation_.unitCorrection;
        }
    }
}
