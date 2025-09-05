// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Non-fungible token for positions
/// @notice Wraps Slipstream positions in a non-fungible token interface which allows for them to be transferred
/// and authorized.
interface INonfungiblePositionManager {
    function approve(address to, uint256 tokenId) external;
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            int24 tickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    function factory() external returns (address factory);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function totalSupply() external view returns (uint256 totalSupply);
}
