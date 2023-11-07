/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface IOracleModule {
    function assetPair(uint256 oracleId) external view returns (bytes16, bytes16);

    function isActive(uint256 oracleId) external view returns (bool);

    /**
     * @notice Returns the rate of two assets.
     * @param oracleId The identifier of the oracle to be checked.
     * @return oracleRate The value of the asset denominated in USD, with 18 Decimals precision.
     * @dev The oracle rate reflects how much of the QuoteAsset is required to buy 1 unit of the BaseAsset
     */
    function getRate(uint256 oracleId) external view returns (uint256);
}
