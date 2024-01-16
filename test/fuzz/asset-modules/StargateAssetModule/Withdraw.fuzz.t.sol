/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test } from "./_StargateAssetModule.fuzz.t.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";

/**
 * @notice Fuzz tests for the function "_withdraw" of contract "StargateAssetModule".
 */
contract Withdraw_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    function testFuzz_success_withdraw(uint256 amount, uint256 poolId) public {
        // Given : Random Stargate pool address.
        address poolLpToken = address(new ERC20Mock("stakingToken", "STK", 0));

        // And: LP tokens are staked in Stargate staking contract.
        mintERC20TokenTo(poolLpToken, address(lpStakingTimeMock), amount);

        // And : Pool token is set for specific pool id in the LPStaking contract.
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, poolLpToken);

        // And : AssetToPoolId mapping is set.
        stargateAssetModule.setAssetToPoolId(poolLpToken, poolId);

        // When : Calling the internal _withdraw function.
        stargateAssetModule.withdrawExtension(poolLpToken, amount);

        // Then : The LP tokens should have been transferred to the AM.
        assertEq(ERC20Mock(poolLpToken).balanceOf(address(stargateAssetModule)), amount);
        assertEq(ERC20Mock(poolLpToken).balanceOf(address(lpStakingTimeMock)), 0);
    }
}
