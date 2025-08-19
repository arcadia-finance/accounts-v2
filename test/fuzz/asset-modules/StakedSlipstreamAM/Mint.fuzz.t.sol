/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { INonfungiblePositionManagerExtension } from
    "../../../utils/fixtures/slipstream/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "mint" of contract "StakedSlipstreamAM".
 */
contract Mint_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
        deployAndAddGauge(0);
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_mint_InvalidId(uint256 assetId) public {
        // Given : assetId is bigger than a type(uint96).max.
        assetId = bound(assetId, uint256(type(uint96).max) + 1, type(uint256).max);

        // When : Calling mint().
        // Then : It should revert.
        vm.expectRevert(StakedSlipstreamAM.InvalidId.selector);
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_Revert_mint_TransferFromFailed(uint96 assetId) public {
        // Given : assetId is not minted.

        // When : Calling mint().
        // Then : It should revert.
        vm.expectRevert("ERC721: operator query for nonexistent token");
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_Revert_mint_ZeroLiquidity(StakedSlipstreamAM.PositionState memory position) public {
        // Given : assetId is minted.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And : Position has zero liquidity.
        (,,,,,,, uint128 liquidity,,,,) = slipstreamPositionManager.positions(assetId);
        vm.prank(users.liquidityProvider);
        slipstreamPositionManager.decreaseLiquidity(
            INonfungiblePositionManagerExtension.DecreaseLiquidityParams({
                tokenId: assetId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );

        // And : Transfer is approved.
        vm.prank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);

        // When : Calling mint().
        // Then : It should revert.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(StakedSlipstreamAM.ZeroLiquidity.selector);
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_Revert_mint_NoGaugeSet(StakedSlipstreamAM.PositionState memory position) public {
        // Given : assetId is minted.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And : Gauge for the pool is not allowed.
        stakedSlipstreamAM.setPoolToGauge(address(pool), address(0));

        // And : Transfer is approved.
        vm.prank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);

        // When : Calling mint().
        // Then : It should revert.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(abi.encodePacked("call to non-contract address ", vm.toString(address(0))));
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_Revert_mint_GaugeIsKilled(StakedSlipstreamAM.PositionState memory position) public {
        // Given : assetId is minted.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And : Gauge is killed.
        voter.setAlive(address(gauge), false);

        // And : Transfer is approved.
        vm.prank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);

        // When : Calling mint().
        // Then : It should revert.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(bytes("GK"));
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_Success_mint(StakedSlipstreamAM.PositionState memory position) public {
        // Given : assetId is minted.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And : Transfer is approved.
        vm.prank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);

        // When : Calling mint().
        vm.prank(users.liquidityProvider);
        stakedSlipstreamAM.mint(assetId);

        // Then : position is minted.
        assertEq(stakedSlipstreamAM.ownerOf(assetId), users.liquidityProvider);

        // And : Position state is updated.
        (int24 tickLower, int24 tickUpper, uint128 liquidity, address gauge_) =
            stakedSlipstreamAM.positionState(assetId);
        uint256 liquidityExpected = getActualLiquidity(position);

        assertEq(tickLower, position.tickLower);
        assertEq(tickUpper, position.tickUpper);
        assertEq(liquidity, liquidityExpected);
        assertEq(gauge_, address(gauge));

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(assetId), address(stakedSlipstreamAM)));
        bytes32[] memory underlyingAssetKeys = stakedSlipstreamAM.getUnderlyingAssets(assetKey);
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(token0))));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(token1))));
        assertEq(underlyingAssetKeys[2], bytes32(abi.encodePacked(uint96(0), AERO)));
    }
}
