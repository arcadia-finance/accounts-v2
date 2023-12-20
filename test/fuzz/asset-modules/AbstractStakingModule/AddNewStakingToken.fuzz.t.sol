/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule } from "./_AbstractStakingModule.fuzz.t.sol";

import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";
import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "addNewStakingToken" of contract "StakingModule".
 */
contract AddNewStakingToken_AbstractAbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_addNewStakingToken_tokenAndRewardPairAlreadySet(
        uint8 underlyingTokenDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : Staking token decimals <= 18
        underlyingTokenDecimals = uint8(bound(underlyingTokenDecimals, 0, 18));
        // Given : RewardToken decimals is <= 18
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 0, 18));

        address underlyingToken = address(new ERC20Mock("xxx", "xxx", underlyingTokenDecimals));
        address rewardToken = address(new ERC20Mock("xxx", "xxx", rewardTokenDecimals));

        // Given : A token/reward pair is set for the first time.
        stakingModule.addNewStakingToken(underlyingToken, rewardToken);

        // When : We try to add the same pair
        // Then : It should revert, as a staking token id already exists for that pair
        vm.expectRevert(StakingModule.TokenToRewardPairAlreadySet.selector);
        stakingModule.addNewStakingToken(underlyingToken, rewardToken);
    }

    function testFuzz_Revert_addNewStakingToken_underlyingTokenDecimalsGreaterThan18(
        uint8 underlyingTokenDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : underlyingToken decimals is > 18
        underlyingTokenDecimals = uint8(bound(underlyingTokenDecimals, 19, type(uint8).max));
        // Given : rewardToken decimals is <= 18
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 0, 18));

        address underlyingToken = address(new ERC20Mock("xxx", "xxx", underlyingTokenDecimals));
        address rewardToken = address(new ERC20Mock("xxx", "xxx", rewardTokenDecimals));

        // When : We try to add a new staking token that has over 18 decimals
        // Then : It should revert
        vm.expectRevert(StakingModule.InvalidTokenDecimals.selector);
        stakingModule.addNewStakingToken(underlyingToken, rewardToken);
    }

    function testFuzz_Revert_addNewStakingToken_rewardTokenDecimalsGreaterThan18(
        uint8 underlyingTokenDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : rewardToken decimals is > 18
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 19, type(uint8).max));
        // Given : underlyingTokenDecimals is <= 18
        underlyingTokenDecimals = uint8(bound(rewardTokenDecimals, 0, 18));

        address underlyingToken = address(new ERC20Mock("xxx", "xxx", underlyingTokenDecimals));
        address rewardToken = address(new ERC20Mock("xxx", "xxx", rewardTokenDecimals));

        // When : We try to add a new staking token that has over 18 decimals
        // Then : It should revert
        vm.expectRevert(StakingModule.InvalidTokenDecimals.selector);
        stakingModule.addNewStakingToken(underlyingToken, rewardToken);
    }

    function testFuzz_Success_addNewStakingToken() public {
        // Given: No staking token previously set
        assertEq(stakingModule.getIdCounter(), 0);

        // When : We add a new staking token with it's respective reward token
        stakingModule.addNewStakingToken(address(mockERC20.stable1), address(mockERC20.token1));

        // Then : Id counter should increase to 1 and staking and reward token should be added with correct info.
        uint256 lastId = stakingModule.getIdCounter();
        assertEq(address(stakingModule.underlyingToken(lastId)), address(mockERC20.stable1));
        assertEq(address(stakingModule.rewardToken(lastId)), address(mockERC20.token1));
        assertEq(stakingModule.tokenToRewardToId(address(mockERC20.stable1), address(mockERC20.token1)), lastId);
        assertEq(lastId, 1);

        // Repeat the above operation for an additional token
        stakingModule.addNewStakingToken(address(mockERC20.token1), address(mockERC20.stable1));

        uint256 lastId2 = stakingModule.getIdCounter();
        assertEq(lastId2, 2);
        assertEq(address(stakingModule.underlyingToken(lastId2)), address(mockERC20.token1));
    }
}
