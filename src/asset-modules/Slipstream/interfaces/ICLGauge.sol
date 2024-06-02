// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.22;

interface ICLGauge {
    function decreaseStakedLiquidity(
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1);
    function deposit(uint256 tokenId) external;
    function earned(address account, uint256 tokenId) external view returns (uint256);
    function getReward(uint256 tokenId) external;
    function increaseStakedLiquidity(
        uint256 tokenId,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1);
    function pool() external returns (address);
    function rewardToken() external returns (address);
    function withdraw(uint256 tokenId) external;
}
