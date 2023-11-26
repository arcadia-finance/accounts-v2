/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

contract RevertingOracle {
    uint8 public decimals;

    function latestRoundData() public pure returns (uint80, int256, uint256, uint256, uint80) {
        revert();
    }
}
