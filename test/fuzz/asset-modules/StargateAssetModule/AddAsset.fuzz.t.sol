/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test, StargateAssetModule } from "./_StargateAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "StargateAssetModule".
 */
contract AddAsset_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
/* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

/*     function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    } */

/*     function testFuzz_Revert_addAsset_AssetNotAllowed(address poolUnderlyingToken, uint256 tokenId, uint256 poolId)
        public
        notTestContracts(poolUnderlyingToken)
    {
        // Given : The pool underlying token is not added to the Registry (see modifier).
        poolMock.setToken(poolUnderlyingToken);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StargateAssetModule.AssetNotAllowed.selector);
        stargateAssetModule.addAsset(tokenId, poolId, address(poolMock));
        vm.stopPrank();
    } */

/*     function testFuzz_Success_addAsset(uint256 tokenId, uint256 stargatePoolId) public {
        // Given : The underlying token of the pool is an asset added to the Registry
        poolMock.setToken(address(mockERC20.token1));

        // And : The pool LP token has already been added in the AM
        stargateAssetModule.setUnderlyingTokenForId(tokenId, address(poolMock));

        // When : Adding an additional asset to the AM (via it's tokenId)
        vm.prank(users.creatorAddress);
        stargateAssetModule.addAsset(tokenId, stargatePoolId, address(poolMock));

        // Then : Information should be set and correct
        assertEq(stargateAssetModule.getTokenIdToPoolId(tokenId), stargatePoolId);

        bytes32 assetModuleKey = stargateAssetModule.getKeyFromAsset(address(stargateAssetModule), tokenId);

        assertEq(stargateAssetModule.getAssetKeyToPool(assetModuleKey), address(poolMock));
        assertEq(
            stargateAssetModule.getAssetToUnderlyingAssets(assetModuleKey),
            stargateAssetModule.getKeyFromAsset(address(mockERC20.token1), 0)
        );
    } */
}
