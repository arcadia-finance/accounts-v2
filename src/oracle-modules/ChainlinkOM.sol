/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { OracleModule } from "./abstracts/AbstractOM.sol";
import { IChainLinkData } from "../interfaces/IChainLinkData.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

/**
 * @title Abstract Oracle Module
 * @author Pragma Labs
 * @notice Oracle Module for Chainlink Oracles.
 */
contract ChainlinkOM is OracleModule {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map oracle => flag.
    mapping(address => bool) internal inOracleModule;

    // Map oracle => oracle identifier.
    mapping(address => uint256) public oracleToOracleId;

    // Map oracle identifier => oracle information.
    mapping(uint256 => OracleInformation) internal oracleInformation;

    struct OracleInformation {
        // The cutoff time after which an oracle is considered stale.
        uint32 cutOffTime;
        // The correction with which the oracle-rate has to be multiplied to get a precision of 18 decimals.
        uint64 unitCorrection;
        // The contract address of the oracle.
        address oracle;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error Max18Decimals();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The contract address of the Registry.
     */
    constructor(address registry_) OracleModule(registry_) { }

    /*///////////////////////////////////////////////////////////////
                          ORACLE MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new oracle to this Oracle Module.
     * @param oracle The contract address of the oracle.
     * @param baseAsset Label for the base asset.
     * @param quoteAsset Label for the quote asset.
     * @return oracleId Unique identifier of the oracle.
     */
    function addOracle(address oracle, bytes16 baseAsset, bytes16 quoteAsset, uint32 cutOffTime)
        external
        onlyOwner
        returns (uint256 oracleId)
    {
        if (inOracleModule[oracle]) revert OracleAlreadyAdded();

        uint256 decimals = IChainLinkData(oracle).decimals();
        if (decimals > 18) revert Max18Decimals();

        inOracleModule[oracle] = true;
        oracleId = IRegistry(REGISTRY).addOracle();

        oracleToOracleId[oracle] = oracleId;
        assetPair[oracleId] = AssetPair({ baseAsset: baseAsset, quoteAsset: quoteAsset });
        oracleInformation[oracleId] =
            OracleInformation({ cutOffTime: cutOffTime, unitCorrection: uint64(10 ** (18 - decimals)), oracle: oracle });
    }

    /*///////////////////////////////////////////////////////////////
                        ORACLE INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the state of an oracle.
     * @param oracleId The identifier of the oracle to be checked.
     * @return oracleIsActive Boolean indicating if the oracle is active or not.
     */
    function isActive(uint256 oracleId) external view override returns (bool oracleIsActive) {
        (oracleIsActive,) = _getLatestAnswer(oracleInformation[oracleId]);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieves answer from oracle and does sanity and staleness checks (BaseAsset/QuoteAsset).
     * @param oracleInformation_ Struct will all the necessary information of the oracle.
     * @return success Bool indicating is the oracle is still active and performing as expected.
     * @return answer The latest oracle value.
     * @dev The following checks are done:
     * - A call to the oracle contract does not revert.
     * - The roundId is not zero.
     * - The answer is not negative.
     * - The oracle is not stale (last update was longer than the cutoff time ago).
     * - The oracle update was not done in the future.
     */
    function _getLatestAnswer(OracleInformation memory oracleInformation_)
        internal
        view
        returns (bool success, uint256 answer)
    {
        try IChainLinkData(oracleInformation_.oracle).latestRoundData() returns (
            uint80 roundId, int256 answer_, uint256, uint256 updatedAt, uint80
        ) {
            if (
                roundId > 0 && answer_ >= 0 && updatedAt > block.timestamp - oracleInformation_.cutOffTime
                    && updatedAt <= block.timestamp
            ) {
                success = true;
                answer = uint256(answer_);
            }
        } catch { }
    }

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
    function getRate(uint256 oracleId) external view override returns (uint256 oracleRate) {
        OracleInformation memory oracleInformation_ = oracleInformation[oracleId];

        (bool success, uint256 answer) = _getLatestAnswer(oracleInformation_);

        // If the oracle is not active, the transactions revert.
        // This implies that no new credit can be taken against assets that use the decommissioned oracle,
        // but at the same time positions with these assets cannot be liquidated.
        // A new oracleSequence for these assets must be set ASAP in their Asset Modules by the protocol owner.
        if (!success) revert InactiveOracle();

        // Only overflows at absurdly large rates, when rate > type(uint256).max / 10 ** (18 - decimals).
        // This is 1.1579209e+59 for an oracle with 0 decimals.
        unchecked {
            oracleRate = answer * oracleInformation_.unitCorrection;
        }
    }
}
