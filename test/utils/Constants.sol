/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

library Constants {
    // Token decimals
    uint256 internal constant STABLE_DECIMALS = 6;
    uint256 internal constant TOKEN_DECIMALS = 18;

    // Token risk factors
    uint16 internal constant STABLE_TO_STABLE_COLL_FACTOR = 10_000;
    uint16 internal constant STABLE_TO_STABLE_LIQ_FACTOR = 10_000;
    uint16 internal constant TOKEN_TO_STABLE_COLL_FACTOR = 8000;
    uint16 internal constant TOKEN_TO_STABLE_LIQ_FACTOR = 9000;
    uint16 internal constant TOKEN_TO_TOKEN_COLL_FACTOR = 5000;
    uint16 internal constant TOKEN_TO_TOKEN_LIQ_FACTOR = 8000;

    // Oracle decimals
    uint256 internal constant STABLE_ORACLE_DECIMALS = 18;
    uint256 internal constant TOKEN_ORACLE_DECIMALS = 8;
    uint256 internal constant NFT_ORACLE_DECIMALS = 8;
    uint256 internal constant SFT_ORACLE_DECIMALS = 10;

    // See src/test_old/MerkleTrees
    bytes32 internal constant PROOF_3_TO_4 = keccak256(abi.encodePacked(uint256(3), uint256(4)));
    bytes32 internal constant PROOF_4_TO_3 = keccak256(abi.encodePacked(uint256(4), uint256(3)));
    bytes32 internal constant ROOT = 0x99944c1b57b38263b300dc18654ff59ce2e057f927d68306cf820299735acac1;

    // Those are fixed values set for the instance of "creditorWithParams"
    address internal constant LIQUIDATOR = address(666);
    uint96 internal constant MINIMUM_MARGIN = 100;

    // Math
    uint256 internal constant WAD = 1e18;

    // Uniswap V3 Pool
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
}
