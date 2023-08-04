/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */

pragma solidity ^0.8.13;

library Constants {
    // Token decimals
    uint256 internal constant stableDecimals = 6;
    uint256 internal constant tokenDecimals = 18;

    // Oracle decimals
    uint256 internal constant stableOracleDecimals = 18;
    uint256 internal constant tokenOracleDecimals = 8;
    uint256 internal constant nftOracleDecimals = 8;
    uint256 internal constant erc1155OracleDecimals = 10;
}
