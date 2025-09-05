/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

library Constants {
    // Token decimals
    uint256 internal constant stableDecimals = 6;
    uint256 internal constant tokenDecimals = 18;

    // Token risk factors
    uint16 internal constant stableToStableCollFactor = 10_000;
    uint16 internal constant stableToStableLiqFactor = 10_000;
    uint16 internal constant tokenToStableCollFactor = 8000;
    uint16 internal constant tokenToStableLiqFactor = 9000;
    uint16 internal constant tokenToTokenCollFactor = 5000;
    uint16 internal constant tokenToTokenLiqFactor = 8000;

    // Oracle decimals
    uint256 internal constant stableOracleDecimals = 18;
    uint256 internal constant tokenOracleDecimals = 8;
    uint256 internal constant nftOracleDecimals = 8;
    uint256 internal constant erc1155OracleDecimals = 10;

    // See src/test_old/MerkleTrees
    bytes32 internal constant upgradeProof3To4 = keccak256(abi.encodePacked(uint256(3), uint256(4)));
    bytes32 internal constant upgradeProof4To3 = keccak256(abi.encodePacked(uint256(4), uint256(3)));
    bytes32 internal constant upgradeRoot3To4And4To3 =
        0x99944c1b57b38263b300dc18654ff59ce2e057f927d68306cf820299735acac1;

    // Those are fixed values set for the instance of "creditorWithParams"
    address internal constant initLiquidator = address(666);
    uint96 internal constant initLiquidationCost = 100;

    // Math
    uint256 internal constant WAD = 1e18;
}
