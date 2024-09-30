/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { PoolKey } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolKey.sol";
import {
    PositionInfo, PositionInfoLibrary
} from "../../../../lib/v4-periphery-fork/src/libraries/PositionInfoLibrary.sol";
import { UniswapV4AM_Fuzz_Test } from "./_UniswapV4AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getPosition" of contract "UniswapV4AM".
 */
contract GetPosition_UniswapV4AM_Fuzz_Test is UniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getPosition_inAM(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint128 updatedLiquidity,
        uint96 tokenId
    ) public {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Liquidity is not-zero
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // And : asset is added to AM
        vm.prank(users.owner);
        uniswapV4AM.addAsset(tokenId);

        // And : The liquidity of the position changes
        vm.assume(updatedLiquidity != liquidity);
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, updatedLiquidity);

        // When : "getPosition is called."
        (PoolKey memory poolKey, PositionInfo info, uint128 liquidity_) = uniswapV4AM.getPosition(tokenId);

        // Then : The correct return variables are returned.
        PositionInfo info_ = PositionInfoLibrary.initialize(stablePoolKey, tickLower, tickUpper);
        assertEq(abi.encode(poolKey), abi.encode(stablePoolKey));
        assertEq(PositionInfo.unwrap(info_), PositionInfo.unwrap(info));
        assertEq(liquidity_, liquidity);
    }

    function testFuzz_Success_getPosition_notInAM(int24 tickLower, int24 tickUpper, uint128 liquidity, uint96 tokenId)
        public
    {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Liquidity is not-zero
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // And : The position is not added to the AM.

        // When : "getPosition is called."
        (PoolKey memory poolKey, PositionInfo info, uint128 liquidity_) = uniswapV4AM.getPosition(tokenId);

        // Then : The correct return variables are returned.
        PositionInfo info_ = PositionInfoLibrary.initialize(stablePoolKey, tickLower, tickUpper);
        assertEq(abi.encode(poolKey), abi.encode(stablePoolKey));
        assertEq(PositionInfo.unwrap(info_), PositionInfo.unwrap(info));
        assertEq(liquidity_, liquidity);
    }
}
