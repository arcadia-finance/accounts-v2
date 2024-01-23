/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeAssetModule_Fuzz_Test } from "./_AerodromeAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "AerodromeAssetModule".
 */
contract GetUnderlyingAssets_AerodromeAssetModule_Fuzz_Test is AerodromeAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssets(uint96 positionId) public {
        // Given : The Asset is added to the AM
        pool.setTokens(address(mockERC20.token1), address(mockERC20.stable1));
        vm.prank(users.creatorAddress);
        aerodromeAssetModule.addAsset(address(pool), address(gauge));

        // Given : Set Asset for positionId
        aerodromeAssetModule.setAssetInPosition(address(pool), positionId);

        // When : Calling getUnderlyingAssets()
        bytes32 assetKey = aerodromeAssetModule.getKeyFromAsset(address(aerodromeAssetModule), positionId);
        bytes32[] memory underlyingAssetKeys = aerodromeAssetModule.getUnderlyingAssets(assetKey);

        // Then : It should return the correct values
        assertEq(underlyingAssetKeys[0], aerodromeAssetModule.getKeyFromAsset(address(mockERC20.token1), 0));
        assertEq(underlyingAssetKeys[1], aerodromeAssetModule.getKeyFromAsset(address(mockERC20.stable1), 0));
        assertEq(
            underlyingAssetKeys[2], aerodromeAssetModule.getKeyFromAsset(address(aerodromeAssetModule.rewardToken()), 0)
        );
    }
}
