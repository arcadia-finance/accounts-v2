// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IUniswapV3PoolExtension } from
    "../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import {
    PoolAddress,
    PoolAddressExtension
} from "../../utils/fixtures/uniswap-v3/extensions/libraries/PoolAddressExtension.sol";

contract NonfungiblePositionManagerMock {
    address public immutable factory;

    mapping(address => uint80) internal _poolIds;

    mapping(uint80 => PoolAddress.PoolKey) private _poolIdToPoolKey;

    mapping(uint256 => Position) private _positions;

    // details about the uniswap position
    struct Position {
        // the nonce for permits
        uint96 nonce;
        // the address that is approved for spending this token
        address operator;
        // the ID of the pool with which this token is connected
        uint80 poolId;
        // the tick range of the position
        int24 tickLower;
        int24 tickUpper;
        // the liquidity of the position
        uint128 liquidity;
        // the fee growth of the aggregate position as of the last action on the individual position
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // how many uncollected tokens are owed to the position, as of the last computation
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    constructor(address factory_) {
        factory = factory_;
    }

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position memory position = _positions[tokenId];
        require(position.poolId != 0, "Invalid token ID");
        PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
        return (
            position.nonce,
            position.operator,
            poolKey.token0,
            poolKey.token1,
            poolKey.fee,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            position.feeGrowthInside0LastX128,
            position.feeGrowthInside1LastX128,
            position.tokensOwed0,
            position.tokensOwed1
        );
    }

    function setPool(address pool, uint80 poolId) public {
        address token0 = IUniswapV3PoolExtension(pool).token0();
        address token1 = IUniswapV3PoolExtension(pool).token1();
        uint24 fee = IUniswapV3PoolExtension(pool).fee();

        PoolAddress.PoolKey memory poolKey = PoolAddressExtension.getPoolKey(token0, token1, fee);

        _poolIds[pool] = poolId;
        _poolIdToPoolKey[poolId] = poolKey;
    }

    function setPosition(address pool, uint256 tokenId, Position calldata position) external {
        setPool(pool, position.poolId);

        _positions[tokenId] = position;
    }
}
