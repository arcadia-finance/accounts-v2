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

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_success_stake(uint256 amount, uint96 poolId) public {
        // Given : Random Stargate pool address.
        address poolLpToken = address(new ERC20Mock("stakingToken", "STK", 0));

        // And: Tokens are transfered directly to the AM (transferFrom happens in external stake() and is covered by our testing of the staking module).
        mintERC20TokenTo(poolLpToken, address(stargateAssetModule), amount);

        // And : Pool token is set for specific pool id in the LPStaking contract.
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, poolLpToken);

        // And : AssetToPoolId mapping is set.
        stargateAssetModule.setAssetToPoolId(poolLpToken, poolId);

        // When : Calling the internal _stake function.
        stargateAssetModule.stakeExtension(poolLpToken, amount);

        // Then : The LP tokens should have been transferred to the LPStakingContract.
        assertEq(ERC20Mock(poolLpToken).balanceOf(address(stargateAssetModule)), 0);
        assertEq(ERC20Mock(poolLpToken).balanceOf(address(lpStakingTimeMock)), amount);
    }
}
