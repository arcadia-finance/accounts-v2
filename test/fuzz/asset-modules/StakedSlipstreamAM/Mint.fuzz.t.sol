/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import {
    INonfungiblePositionManagerExtension
} from "../../../utils/fixtures/slipstream/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "mint" of contract "StakedSlipstreamAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract Mint_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_mint_InvalidId(uint256 assetId, address sender) public {
        // Given: The asset id does not fit the uint96 the asset key packs it into.
        assetId = bound(assetId, uint256(type(uint96).max) + 1, type(uint256).max);

        // When: The sender mints the position.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert(StakedSlipstreamAM.InvalidId.selector);
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_Revert_mint_TransferFromFailed(uint96 assetId, address sender) public {
        // Given: The asset id is not minted by the Position Manager.

        // When: The sender mints the position.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert("ERC721: operator query for nonexistent token");
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_Revert_mint_ZeroLiquidity(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: A gauge on a pool.
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);

        // And: A valid position of the liquidity provider.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And: All liquidity is removed from the position.
        (,,,,,,, uint128 liquidity,,,,) = slipstreamPositionManager.positions(assetId);
        vm.prank(users.liquidityProvider);
        slipstreamPositionManager.decreaseLiquidity(
            INonfungiblePositionManagerExtension.DecreaseLiquidityParams({
                tokenId: assetId, liquidity: liquidity, amount0Min: 0, amount1Min: 0, deadline: type(uint256).max
            })
        );

        // And: The Asset Module is approved to transfer the position.
        vm.prank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);

        // When: The liquidity provider mints the position.
        // Then: It reverts.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(StakedSlipstreamAM.ZeroLiquidity.selector);
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_Revert_mint_NoGaugeSet(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: A gauge on a pool.
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);

        // And: A valid position of the liquidity provider.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And: The pool has no gauge in the Asset Module.
        stakedSlipstreamAM.setPoolToGauge(address(pool), address(0));

        // And: The Asset Module is approved to transfer the position.
        vm.prank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);

        // When: The liquidity provider mints the position.
        // Then: It reverts, the deposit is a call to a non contract address.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(bytes(""));
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_Revert_mint_GaugeIsKilled(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: A gauge on a pool.
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);

        // And: A valid position of the liquidity provider.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And: The gauge is killed.
        voter.setAlive(address(gauge), false);

        // And: The Asset Module is approved to transfer the position.
        vm.prank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);

        // When: The liquidity provider mints the position.
        // Then: It reverts.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(bytes("GK"));
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_Success_mint(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: A gauge on a pool.
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);

        // And: A valid position of the liquidity provider.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And: The Asset Module is approved to transfer the position.
        vm.prank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);

        // When: The liquidity provider mints the position.
        vm.prank(users.liquidityProvider);
        stakedSlipstreamAM.mint(assetId);

        // Then: The position is minted to the liquidity provider.
        assertEq(stakedSlipstreamAM.ownerOf(assetId), users.liquidityProvider);

        // And: The position state is stored.
        (int24 tickLower, int24 tickUpper, uint128 liquidity, address gauge_) =
            stakedSlipstreamAM.positionState(assetId);
        assertEq(tickLower, position.tickLower);
        assertEq(tickUpper, position.tickUpper);
        assertEq(liquidity, getActualLiquidity(position));
        assertEq(gauge_, address(gauge));

        // And: Both pool tokens and the reward token are the underlying assets.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(assetId), address(stakedSlipstreamAM)));
        bytes32[] memory underlyingAssetKeys = stakedSlipstreamAM.getUnderlyingAssets(assetKey);
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(token0))));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(token1))));
        assertEq(underlyingAssetKeys[2], bytes32(abi.encodePacked(uint96(0), AERO)));
    }
}
