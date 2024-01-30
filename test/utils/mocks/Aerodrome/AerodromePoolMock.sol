/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

contract AerodromePoolMock is ERC20 {
    uint256 internal constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 internal constant MINIMUM_K = 10 ** 10;

    address public factory;
    address public token0;
    address public token1;

    uint256 private reserve0;
    uint256 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public decimals0;
    uint256 public decimals1;

    uint256 public kLast;

    bool public stable;

    constructor() ERC20("Aerodrome", "AERO-LP", 18) { }

    error DepositsNotEqual();
    error BelowMinimumK();
    error InsufficientLiquidityMinted();

    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function setTokens(address _token0, address _token1) external {
        token0 = _token0;
        token1 = _token1;
    }

    function setDecimals(uint256 decimals0_, uint256 decimals1_) external {
        decimals0 = decimals0_;
        decimals1 = decimals1_;
    }

    function setStable(bool stable_) public {
        stable = stable_;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    function mint(address to) external returns (uint256 liquidity) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        uint256 _balance0 = ERC20(token0).balanceOf(address(this));
        uint256 _balance1 = ERC20(token1).balanceOf(address(this));
        uint256 _amount0 = _balance0 - _reserve0;
        uint256 _amount1 = _balance1 - _reserve1;

        if (totalSupply == 0) {
            liquidity = FixedPointMathLib.sqrt(_amount0 * _amount1) - MINIMUM_LIQUIDITY;
            _mint(address(1), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens - cannot be address(0)
            if (stable) {
                if ((_amount0 * 1e18) / decimals0 != (_amount1 * 1e18) / decimals1) revert DepositsNotEqual();
                if (_k(_amount0, _amount1) <= MINIMUM_K) revert BelowMinimumK();
            }
        } else {
            liquidity = min((_amount0 * totalSupply) / _reserve0, (_amount1 * totalSupply) / _reserve1);
        }
        if (liquidity == 0) revert InsufficientLiquidityMinted();
        _mint(to, liquidity);

        reserve0 = _balance0;
        reserve1 = _balance1;
    }

    function _k(uint256 x, uint256 y) internal view returns (uint256) {
        if (stable) {
            uint256 _x = (x * 1e18) / decimals0;
            uint256 _y = (y * 1e18) / decimals1;
            uint256 _a = (_x * _y) / 1e18;
            uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
            return (_a * _b) / 1e18; // x3y+y3x >= k
        } else {
            return x * y; // xy >= k
        }
    }

    function setReserves(uint256 _reserve0, uint256 _reserve1) external {
        reserve0 = uint112(_reserve0);
        reserve1 = uint112(_reserve1);
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);
    }

    function swapToken0ToToken1(uint256 amountIn) external returns (uint256 lpGrowth) {
        uint256 amountOut = getAmountOut(amountIn, reserve0, reserve1);
        require(amountOut < reserve1, "UniswapV2: INSUFFICIENT_LIQUIDITY");
        lpGrowth = FixedPointMathLib.WAD * FixedPointMathLib.sqrt((reserve0 + amountIn) * (reserve1 - amountOut))
            / FixedPointMathLib.sqrt(uint256(reserve0) * uint256(reserve1));
        reserve0 = uint112(reserve0 + amountIn);
        reserve1 = uint112(reserve1 - amountOut);
    }

    function swapToken1ToToken0(uint256 amountIn) external returns (uint256 lpGrowth) {
        uint256 amountOut = getAmountOut(amountIn, reserve1, reserve0);
        require(amountOut < reserve0, "UniswapV2: INSUFFICIENT_LIQUIDITY");
        lpGrowth = FixedPointMathLib.WAD * FixedPointMathLib.sqrt((reserve0 - amountOut) * (reserve1 + amountIn))
            / FixedPointMathLib.sqrt(uint256(reserve0) * uint256(reserve1));
        reserve0 = uint112(reserve0 - amountOut);
        reserve1 = uint112(reserve1 + amountIn);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function tokens() public view returns (address token0_, address token1_) {
        return (token0, token1);
    }
}
