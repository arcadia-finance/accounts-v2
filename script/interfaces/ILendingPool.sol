/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

interface ILendingPool {
    function setBorrowCap(uint256 borrowCap) external;

    function setVaultVersion(uint256 version, bool value) external;

    struct InterestRateConfiguration {
        uint72 baseRatePerYear; //18 decimals precision.
        uint72 lowSlopePerYear; //18 decimals precision.
        uint72 highSlopePerYear; //18 decimals precision.
        uint40 utilisationThreshold; //5 decimal precision.
    }

    function setInterestConfig(InterestRateConfiguration calldata interestRateConfiguration) external;
}
