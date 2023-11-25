/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IOracleModule {
    /**
     * @notice Returns the base and quote asset of an oracle.
     * @param oracleId The identifier of the oracle to be checked.
     * @return baseAsset Label for the base asset.
     * @return quoteAsset Label for the quote asset.
     */
    function assetPair(uint256 oracleId) external view returns (bytes16, bytes16);

    /**
     * @notice Returns the state of an oracle.
     * @param oracleId The identifier of the oracle to be checked.
     * @return boolean indicating if the oracle is active or not.
     */
    function isActive(uint256 oracleId) external view returns (bool);

    /**
     * @notice Returns the rate of two assets.
     * @param oracleId The identifier of the oracle to be checked.
     * @return oracleRate The value of the asset denominated in USD, with 18 Decimals precision.
     */
    function getRate(uint256 oracleId) external view returns (uint256);
}
