/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test } from "./_StargateAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "StargateAssetModule".
 */
contract IsAllowed_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    function testFuzz_Success_isAllowed_True(uint256 tokenId, uint256 stargatePoolId) public {
        // Given : stargatePoolId is greater than zero (Stargate has no pools with the 0 id)
        vm.assume(stargatePoolId > 0);

        poolMock.setToken(address(mockERC20.token1));
        stargateAssetModule.setUnderlyingTokenForId(tokenId, address(poolMock));

        // And : The ERC1155 tokenId has already been added to the AM.
        vm.prank(users.creatorAddress);
        stargateAssetModule.addAsset(tokenId, stargatePoolId);

        // When : Calling isAllowed()
        bool allowed = stargateAssetModule.isAllowed(address(stargateAssetModule), tokenId);

        // Then : It should return true
        assertEq(allowed, true);
    }

    function testFuzz_Success_isAllowed_False(uint256 tokenId) public {
        // Given : No ERC1155 tokens have been added yet to the AM.
        // When : Calling isAllowed()
        bool allowed = stargateAssetModule.isAllowed(address(stargateAssetModule), tokenId);
        // Then : It should return
        assertEq(allowed, false);
    }
}
