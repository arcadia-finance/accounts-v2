/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { NonfungiblePositionManagerMock } from "../../../utils/mocks/Slipstream/NonfungiblePositionManager.sol";
import { SlipstreamAM_Fuzz_Test } from "./_SlipstreamAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getPosition" of contract "SlipstreamAM".
 */
contract GetPosition_SlipstreamAM_Fuzz_Test is SlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    address token0;
    address token1;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        SlipstreamAM_Fuzz_Test.setUp();

        (token0, token1) = address(mockERC20.stable1) < address(mockERC20.stable2)
            ? (address(mockERC20.stable1), address(mockERC20.stable2))
            : (address(mockERC20.stable2), address(mockERC20.stable1));

        deploySlipstreamAM(address(nonfungiblePositionManagerMock));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getPosition_InAssetModule(
        uint96 assetId,
        NonfungiblePositionManagerMock.Position memory position,
        uint128 newLiquidity
    ) public {
        // Given: A valid position with liquidity.
        position = givenValidPosition(position);
        vm.assume(position.liquidity != 0);
        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), assetId, position);

        // And: The position is added to the Asset Module.
        slipstreamAM.addAsset(assetId);

        // And: The liquidity of the position changes afterwards.
        uint256 liquidityAtDeposit = position.liquidity;
        position.liquidity = newLiquidity;
        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), assetId, position);

        // When: The position is read.
        (address token0_, address token1_, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            slipstreamAM.getPosition(assetId);

        // Then: Both pool tokens and the tick range of the position are returned.
        assertEq(token0_, token0);
        assertEq(token1_, token1);
        assertEq(tickLower, position.tickLower);
        assertEq(tickUpper, position.tickUpper);

        // And: The liquidity stored at the time of the deposit is returned.
        assertEq(liquidity, liquidityAtDeposit);
    }

    function testFuzz_Success_getPosition_NotInAssetModule(
        uint96 assetId,
        NonfungiblePositionManagerMock.Position memory position,
        uint128 newLiquidity
    ) public {
        // Given: A valid position that is not added to the Asset Module.
        position = givenValidPosition(position);
        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), assetId, position);

        // When: The position is read.
        (address token0_, address token1_, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            slipstreamAM.getPosition(assetId);

        // Then: Both pool tokens, the tick range and the current liquidity are returned.
        assertEq(token0_, token0);
        assertEq(token1_, token1);
        assertEq(tickLower, position.tickLower);
        assertEq(tickUpper, position.tickUpper);
        assertEq(liquidity, position.liquidity);

        // And: The liquidity of the position changes.
        position.liquidity = newLiquidity;
        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), assetId, position);

        // When: The position is read again.
        (,,,, liquidity) = slipstreamAM.getPosition(assetId);

        // Then: The current liquidity is returned.
        assertEq(liquidity, newLiquidity);
    }
}
