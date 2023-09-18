/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

contract RevertingOracle {
    function latestRoundData() public pure returns (uint80, int256, uint256, uint256, uint80) {
        revert();
    }
}
