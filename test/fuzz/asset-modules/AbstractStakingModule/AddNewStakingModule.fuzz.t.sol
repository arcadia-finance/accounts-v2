/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test } from "./_AbstractStakingModule.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "addNewStakingToken" of contract "AbstractStakingModule".
 */
contract AddNewStakingToken_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_success_addNewStakingToken() public {
        // Add new staking and reward token
        stakingModule.addNewStakingToken(address(mockERC20.stable1), address(mockERC20.token1));

        uint256 idCounter = stakingModule.getIdCounter();

        assertEq(address(stakingModule.stakingToken(idCounter)), address(mockERC20.stable1));
        assertEq(address(stakingModule.rewardToken(idCounter)), address(mockERC20.token1));
        assertEq(stakingModule.stakingTokenDecimals(idCounter), mockERC20.stable1.decimals());
        assertEq(stakingModule.stakingTokenToId(address(mockERC20.stable1)), idCounter);
        assertEq(idCounter, 1);

        // Add new staking and reward token
        stakingModule.addNewStakingToken(address(mockERC20.token1), address(mockERC20.stable1));

        uint256 idCounter2 = stakingModule.getIdCounter();
        assertEq(idCounter2, 2);
        assertEq(address(stakingModule.stakingToken(idCounter2)), address(mockERC20.token1));
    }
}