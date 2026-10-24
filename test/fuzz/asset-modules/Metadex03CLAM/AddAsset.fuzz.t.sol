/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Metadex03CLAM_Fuzz_Test } from "./_Metadex03CLAM.fuzz.t.sol";
import { NonfungiblePositionManagerMock } from "../../../utils/mocks/Slipstream/NonfungiblePositionManager.sol";
import { SlipstreamAM } from "../../../../src/asset-modules/Slipstream/SlipstreamAM.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "Metadex03CLAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract AddAsset_Metadex03CLAM_Fuzz_Test is Metadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    address token0;
    address token1;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Metadex03CLAM_Fuzz_Test.setUp();

        (token0, token1) = address(mockERC20.stable1) < address(mockERC20.stable2)
            ? (address(mockERC20.stable1), address(mockERC20.stable2))
            : (address(mockERC20.stable2), address(mockERC20.stable1));

        deployMetadex03CLAM(address(nonfungiblePositionManagerMock));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_addAsset_IdTooLarge(
        uint256 tokenId,
        NonfungiblePositionManagerMock.Position memory position
    ) public {
        // Given: A position with an id that does not fit in a uint96.
        tokenId = bound(tokenId, uint256(type(uint96).max) + 1, type(uint256).max);
        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), tokenId, position);

        // When: The asset is added to the Asset Module.
        // Then: It reverts.
        vm.expectRevert(SlipstreamAM.InvalidId.selector);
        metadex03CLAM.addAsset(tokenId);
    }

    function testFuzz_Revert_addAsset_ZeroLiquidity(
        uint96 tokenId,
        NonfungiblePositionManagerMock.Position memory position
    ) public {
        // Given: A valid position without liquidity.
        position = givenValidPosition(position);
        position.liquidity = 0;
        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), tokenId, position);

        // When: The asset is added to the Asset Module.
        // Then: It reverts.
        vm.expectRevert(SlipstreamAM.ZeroLiquidity.selector);
        metadex03CLAM.addAsset(tokenId);
    }

    function testFuzz_Success_addAsset(uint96 tokenId, NonfungiblePositionManagerMock.Position memory position) public {
        // Given: A valid position with liquidity.
        position = givenValidPosition(position);
        vm.assume(position.liquidity != 0);
        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), tokenId, position);

        // When: The asset is added to the Asset Module.
        metadex03CLAM.addAsset(tokenId);

        // Then: The liquidity of the position at the time of the deposit is stored.
        assertEq(metadex03CLAM.getAssetToLiquidity(tokenId), position.liquidity);

        // And: The keys of both pool tokens are stored as the underlying assets.
        bytes32[] memory underlyingAssetKeys = metadex03CLAM.getUnderlyingAssets(
            bytes32(abi.encodePacked(tokenId, address(nonfungiblePositionManagerMock)))
        );
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), token0)));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), token1)));
    }
}
