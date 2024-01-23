/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test } from "./_StargateAssetModule.fuzz.t.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";

/**
 * @notice Fuzz tests for the function "_stake" of contract "StargateAssetModule".
 */
contract Stake_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
/* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

/*     function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    } */

/*     function testFuzz_success_stake(address staker, uint256 tokenId, uint256 amount, uint256 poolId) public {
        // Given : Random Stargate pool address.
        address poolLpToken = address(new ERC20Mock("stakingToken", "STK", 0));

        // And: Tokens are transfered directly to the AM (transferFrom happens in external stake() and is covered by our testing of the staking module).
        mintERC20TokenTo(poolLpToken, address(stargateAssetModule), amount);

        // And : Pool token is set for specific pool id in the LPStaking contract.
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, poolLpToken);

        // And : Set underlying token for tokenId.
        stargateAssetModule.setUnderlyingTokenForId(tokenId, poolLpToken);

        // And : Mapping is set for ERC155 token id to Stargate pool id.
        stargateAssetModule.setTokenIdToPoolId(tokenId, poolId);

        // When : Calling the internal _stake function.
        vm.prank(staker);
        stargateAssetModule.stakeExtension(tokenId, amount);

        // Then : The LP tokens should have been transferred to the LPStakingContract.
        assertEq(ERC20Mock(poolLpToken).balanceOf(address(stargateAssetModule)), 0);
        assertEq(ERC20Mock(poolLpToken).balanceOf(address(lpStakingTimeMock)), amount);
    } */
}
