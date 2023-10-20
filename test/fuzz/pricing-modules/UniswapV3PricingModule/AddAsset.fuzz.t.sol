/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3Fixture, UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

import { NonfungiblePositionManagerMock } from "../../../utils/mocks/NonfungiblePositionManager.sol";
import { UniswapV3PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "addAsset" of contract "UniswapV3PricingModule".
 */
contract AddAsset_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();

        deployUniswapV3PricingModule(address(nonfungiblePositionManagerMock));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_addAsset_IdToLarge(
        uint256 tokenId,
        NonfungiblePositionManagerMock.Position memory position
    ) public {
        tokenId = bound(tokenId, uint256(type(uint96).max) + 1, type(uint256).max);

        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), tokenId, position);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PMUV3_AA: Id too large");
        uniV3PricingModule.addAsset(tokenId);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_ZeroLiquidity(
        uint96 tokenId,
        NonfungiblePositionManagerMock.Position memory position
    ) public {
        // Given: position is valid.
        position = givenValidPosition(position);

        // And: Liquidity is zero (test-case).
        position.liquidity = 0;

        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), tokenId, position);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PMUV3_AA: 0 liquidity");
        uniV3PricingModule.addAsset(tokenId);
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(uint96 tokenId, NonfungiblePositionManagerMock.Position memory position)
        public
    {
        // Given: position is valid.
        position = givenValidPosition(position);

        // And: Liquidity is not-zero (see testFuzz_Revert_addAsset_ZeroLiquidity).
        position.liquidity = uint128(bound(position.liquidity, 1, type(uint128).max));

        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), tokenId, position);

        vm.prank(users.creatorAddress);
        uniV3PricingModule.addAsset(tokenId);

        assertEq(uniV3PricingModule.getAssetToLiquidity(tokenId), position.liquidity);

        bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(nonfungiblePositionManagerMock)));
        bytes32[] memory underlyingAssetKeys = uniV3PricingModule.getUnderlyingAssets(assetKey);

        (address token0, address token1) = address(mockERC20.stable1) < address(mockERC20.stable2)
            ? (address(mockERC20.stable1), address(mockERC20.stable2))
            : (address(mockERC20.stable2), address(mockERC20.stable1));

        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), token0)));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), token1)));
    }
}
