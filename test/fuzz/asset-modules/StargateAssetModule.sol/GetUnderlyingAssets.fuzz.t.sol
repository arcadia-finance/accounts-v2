/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test } from "./_StargateAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "StargateAssetModule".
 */
contract GetUnderlyingAssets_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    function testFuzz_Success_getUnderlyingAssets(uint256 tokenId, uint256 stargatePoolId) public {
        // Given : The pool deposit token (the underlying token) is set in the mocked pool contract. And is an asset that was previously added to the registry.
        poolMock.setToken(address(mockERC20.token1));

        // And : The ERC1155 token is added to the AM.
        vm.prank(users.creatorAddress);
        stargateAssetModule.addAsset(tokenId, stargatePoolId, address(poolMock));

        bytes32 assetKey = stargateAssetModule.getKeyFromAsset(address(stargateAssetModule), tokenId);

        // When : Calling _getUnderlyingAssets()
        bytes32[] memory underlyingAssetKeys = stargateAssetModule.getUnderlyingAssets(assetKey);

        // Then : The assetKey returned should be correct
        bytes32 underlyingTokenAssetKey = stargateAssetModule.getKeyFromAsset(address(mockERC20.token1), 0);

        assertEq(underlyingAssetKeys[0], underlyingTokenAssetKey);
    }
}
