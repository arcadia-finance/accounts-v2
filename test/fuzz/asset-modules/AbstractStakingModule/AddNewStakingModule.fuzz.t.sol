/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, AbstractStakingModule } from "./_AbstractStakingModule.fuzz.t.sol";

import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";
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

    function testFuzz_revert_addNewStakingToken_tokenAndRewardPairAlreadySet(
        uint8 stakingTokenDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : Staking token decimals <= 18
        stakingTokenDecimals = uint8(bound(stakingTokenDecimals, 0, 18));
        // Given : RewardToken decimals is <= 18
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 0, 18));

        address stakingToken = address(new ERC20Mock("xxx", "xxx", stakingTokenDecimals));
        address rewardToken = address(new ERC20Mock("xxx", "xxx", rewardTokenDecimals));

        // Given : A token/reward pair is set for the first time.
        stakingModule.addNewStakingToken(stakingToken, rewardToken);

        // When : We try to add the same pair
        // Then : It should revert, as a token id already exists for that pair
        vm.expectRevert(AbstractStakingModule.TokenToRewardPairAlreadySet.selector);
        stakingModule.addNewStakingToken(stakingToken, rewardToken);
    }

    function testFuzz_revert_addNewStakingToken_stakingTokenDecimalsGreaterThan18(
        uint8 stakingTokenDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : stakingToken decimals is > 18
        stakingTokenDecimals = uint8(bound(stakingTokenDecimals, 19, type(uint8).max));
        // Given : rewardToken decimals is <= 18
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 0, 18));

        address stakingToken = address(new ERC20Mock("xxx", "xxx", stakingTokenDecimals));
        address rewardToken = address(new ERC20Mock("xxx", "xxx", rewardTokenDecimals));

        // When : We try to add a new staking token that has over 18 decimals
        // Then : It should revert
        vm.expectRevert(AbstractStakingModule.InvalidTokenDecimals.selector);
        stakingModule.addNewStakingToken(stakingToken, rewardToken);
    }

    function testFuzz_revert_addNewStakingToken_rewardTokenDecimalsGreaterThan18(
        uint8 stakingTokenDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : rewardToken decimals is > 18
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 19, type(uint8).max));
        // Given : stakingTokenDecimals is <= 18
        stakingTokenDecimals = uint8(bound(rewardTokenDecimals, 0, 18));

        address stakingToken = address(new ERC20Mock("xxx", "xxx", stakingTokenDecimals));
        address rewardToken = address(new ERC20Mock("xxx", "xxx", rewardTokenDecimals));

        // When : We try to add a new staking token that has over 18 decimals
        // Then : It should revert
        vm.expectRevert(AbstractStakingModule.InvalidTokenDecimals.selector);
        stakingModule.addNewStakingToken(stakingToken, rewardToken);
    }

    function testFuzz_success_addNewStakingToken() public {
        // Given: No staking token previously set
        assertEq(stakingModule.getIdCounter(), 0);

        // When : We add a new staking token with it's respective reward token
        stakingModule.addNewStakingToken(address(mockERC20.stable1), address(mockERC20.token1));

        // Then : Id counter should increase to 1 and staking and reward token should be added with correct info.
        uint256 idCounter = stakingModule.getIdCounter();
        assertEq(address(stakingModule.stakingToken(idCounter)), address(mockERC20.stable1));
        assertEq(address(stakingModule.rewardToken(idCounter)), address(mockERC20.token1));
        assertEq(stakingModule.tokenToRewardToId(address(mockERC20.stable1), address(mockERC20.token1)), idCounter);
        assertEq(idCounter, 1);

        // Repeat the above operation for an additional token
        stakingModule.addNewStakingToken(address(mockERC20.token1), address(mockERC20.stable1));

        uint256 idCounter2 = stakingModule.getIdCounter();
        assertEq(idCounter2, 2);
        assertEq(address(stakingModule.stakingToken(idCounter2)), address(mockERC20.token1));
    }
}
