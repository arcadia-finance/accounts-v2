/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test, StargatePoolMock } from "./_StargateAssetModule.fuzz.t.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";

/**
 * @notice Fuzz tests for the function "addNewStakingToken" of contract "StargateAssetModule".
 */
contract AddNewStakingToken_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    function testFuzz_Revert_addNewStakingToken_NotOwner(address unprivilegedAddress_, address asset, uint256 poolId)
        public
    {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        stargateAssetModule.addNewStakingToken(asset, poolId);
        vm.stopPrank();
    }

    function testFuzz_Success_addNewStakingToken(uint256 decimals, uint256 poolId) public {
        // Given : Decimals are max 18
        decimals = bound(decimals, 0, 18);
        address stakingToken = address(new StargatePoolMock(uint8(decimals)));
        address rewardToken = address(new ERC20Mock("", "", uint8(decimals)));

        // And : The underlying token of the Stargate Pool is already added in the Registry.
        StargatePoolMock(stakingToken).setToken(address(mockERC20.token1));

        // And : rewardToken is set
        lpStakingTimeMock.setEToken(rewardToken);

        // When : We add a new staking token
        vm.prank(users.creatorAddress);
        stargateAssetModule.addNewStakingToken(stakingToken, poolId);

        // Then : Id counter should increase to 1 and all info should be correct.
        uint256 tokenId = stargateAssetModule.getIdCounter();
        assertEq(address(stargateAssetModule.underlyingToken(tokenId)), stakingToken);
        assertEq(address(stargateAssetModule.rewardToken(tokenId)), rewardToken);
        assertEq(stargateAssetModule.tokenToRewardToId(stakingToken, rewardToken), tokenId);
        assertEq(tokenId, 1);

        assertEq(stargateAssetModule.getTokenIdToPoolId(tokenId), poolId);

        bytes32 assetModuleKey = stargateAssetModule.getKeyFromAsset(address(stargateAssetModule), tokenId);

        assertEq(stargateAssetModule.getAssetKeyToPool(assetModuleKey), stakingToken);
        assertEq(
            stargateAssetModule.getAssetToUnderlyingAssets(assetModuleKey),
            stargateAssetModule.getKeyFromAsset(address(mockERC20.token1), 0)
        );
    }
}
