/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

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
        deployAndAddGauge();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_revert_mint_InvalidId(uint256 assetId) public {
        // Given : assetId is bigger than a type(uint96).max.
        assetId = bound(assetId, uint256(type(uint96).max) + 1, type(uint256).max);

        // When : Calling mint().
        // Then : It should revert.
        vm.expectRevert(StakedSlipstreamAM.InvalidId.selector);
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_revert_mint_TransferFromFailed(uint96 assetId) public {
        // Given : assetId is not minted.

        // When : Calling mint().
        // Then : It should revert.
        vm.expectRevert("ERC721: operator query for nonexistent token");
        stakedSlipstreamAM.mint(assetId);
    }

    function testFuzz_revert_mint_ZeroLiquidity(StakedSlipstreamAM.PositionState memory position) public {
        // Given : assetId is minted.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And : Position has zero liquidity.
        (,,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(assetId);
        vm.prank(users.liquidityProvider);
        nonfungiblePositionManager.decreaseLiquidity(
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
        nonfungiblePositionManager.approve(address(stakedSlipstreamAM), assetId);

        // When : Calling mint().
        // Then : It should revert.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(StakedSlipstreamAM.ZeroLiquidity.selector);
        stakedSlipstreamAM.mint(assetId);
    }
}
