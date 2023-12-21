// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

// @notice Interface for ChainLink Data Feed, it is based on https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol
interface IChainLinkData {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
