/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { StakingAM } from "../../../../src/asset-modules/abstracts/AbstractStakingAM.sol";
import { StakingAMMock } from "../../../utils/mocks/asset-modules/StakingAMMock.sol";

/**
 * @notice Common logic needed by "StakingAM" fuzz tests.
 */
// forge-lint: disable-next-item(unsafe-typecast)
abstract contract AbstractStakingAM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-start(pascal-case-struct)
    struct StakingAMStateForAsset {
        uint256 currentRewardGlobal;
        uint128 lastRewardPerTokenGlobal;
        uint128 totalStaked;
    }

    struct StakingAMStateForPosition {
        address asset;
        uint128 amountStaked;
        uint128 lastRewardPerTokenPosition;
        uint128 lastRewardPosition;
    }

    struct StakingAMStateForSurplus {
        uint256 bookedSurplus;
        uint256 lastRewardBalance;
        address surplusRecipient;
    }
    // forge-lint: disable-end(pascal-case-struct)

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ERC20Mock internal rewardToken;
    // forge-lint: disable-next-line(mixed-case-variable)
    StakingAMMock internal stakingAM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.owner);
        rewardToken = new ERC20Mock("RewardToken", "RWT", 18);
        stakingAM = new StakingAMMock(
            users.owner, address(registry), "StakingAMTest", "SMT", address(rewardToken), users.treasury
        );
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    // Excludes the addresses whose Reward Token balance a sweep assertion reads.
    function _givenValidRecipient(address recipient) internal view {
        vm.assume(recipient != address(0));
        vm.assume(recipient.code.length == 0);
        vm.assume(recipient != users.accountOwner);
        vm.assume(recipient != users.liquidityProvider);
    }

    // forge-lint: disable-next-item(mixed-case-function,mixed-case-variable)
    function setStakingAMState(
        StakingAMStateForAsset memory stakingAMStateForAsset,
        StakingAM.PositionState memory stakingAMStateForPosition,
        StakingAMStateForSurplus memory stakingAMStateForSurplus,
        address asset,
        uint96 id
    ) internal {
        stakingAM.setTotalStaked(asset, stakingAMStateForAsset.totalStaked);
        stakingAM.setLastRewardPosition(id, stakingAMStateForPosition.lastRewardPosition);
        stakingAM.setLastRewardPerTokenPosition(id, stakingAMStateForPosition.lastRewardPerTokenPosition);
        stakingAM.setLastRewardPerTokenGlobal(asset, stakingAMStateForAsset.lastRewardPerTokenGlobal);
        stakingAM.setActualRewardBalance(asset, stakingAMStateForAsset.currentRewardGlobal);
        stakingAM.setAmountStakedForPosition(id, stakingAMStateForPosition.amountStaked);
        stakingAMStateForPosition.asset = asset;
        stakingAM.setAssetInPosition(asset, id);

        setStakingAMState(stakingAMStateForSurplus);
    }

    // forge-lint: disable-next-item(mixed-case-function,mixed-case-variable)
    function setStakingAMState(StakingAMStateForSurplus memory stakingAMStateForSurplus) internal {
        deal(address(rewardToken), address(stakingAM), stakingAMStateForSurplus.lastRewardBalance, true);
        stakingAM.setLastRewardBalance(stakingAMStateForSurplus.lastRewardBalance);
        stakingAM.setBookedSurplus(stakingAMStateForSurplus.bookedSurplus);
        vm.prank(users.owner);
        stakingAM.setSurplusRecipient(stakingAMStateForSurplus.surplusRecipient);
    }

    // forge-lint: disable-next-item(mixed-case-function,mixed-case-variable)
    function givenValidStakingAMState(
        StakingAMStateForAsset memory stakingAMStateForAsset,
        StakingAM.PositionState memory stakingAMStateForPosition,
        StakingAMStateForSurplus memory stakingAMStateForSurplus,
        uint128 minAmountStaked,
        uint128 maxTotalStaked
    ) public view returns (StakingAMStateForAsset memory, StakingAM.PositionState memory) {
        // Given: More than 1 gwei is staked.
        stakingAMStateForAsset.totalStaked = uint128(
            bound(stakingAMStateForAsset.totalStaked, minAmountStaked == 0 ? 1 : minAmountStaked, maxTotalStaked)
        );

        // And: totalStaked should be >= to amountStakedForPosition (invariant).
        stakingAMStateForPosition.amountStaked = uint128(
            bound(stakingAMStateForPosition.amountStaked, minAmountStaked, stakingAMStateForAsset.totalStaked)
        );

        // And: the reward stays below the amount that makes the mulDivDown of the delta revert.
        stakingAMStateForAsset.currentRewardGlobal =
            bound(stakingAMStateForAsset.currentRewardGlobal, 1, type(uint256).max / 1e18);

        // Calculate the new rewardPerTokenGlobal.
        uint128 rewardPerToken = currentRewardPerTokenGlobal(stakingAMStateForAsset);

        // And: Previously earned rewards for Account + new rewards does not overflow.
        // -> deltaReward of the position is smaller or equal to type(uint128).max (overflow).
        // -> deltaRewardPerToken * positionState_.amountStaked / 1e18 <= type(uint128).max;
        uint256 deltaRewardPerToken;
        unchecked {
            deltaRewardPerToken = rewardPerToken - stakingAMStateForPosition.lastRewardPerTokenPosition;
        }
        if (stakingAMStateForPosition.amountStaked > 0) {
            deltaRewardPerToken = uint128(
                bound(
                    deltaRewardPerToken, 0, type(uint128).max * uint256(1e18) / stakingAMStateForPosition.amountStaked
                )
            );
        }
        unchecked {
            stakingAMStateForPosition.lastRewardPerTokenPosition = rewardPerToken - uint128(deltaRewardPerToken);
        }
        uint256 deltaReward = deltaRewardPerToken * uint256(stakingAMStateForPosition.amountStaked) / 1e18;

        // And: Previously earned rewards for Account + new rewards does not overflow.
        // -> lastRewardPosition + deltaReward <= type(uint128).max;
        stakingAMStateForPosition.lastRewardPosition =
            uint128(bound(stakingAMStateForPosition.lastRewardPosition, 0, type(uint128).max - deltaReward));

        givenValidStakingAMState(stakingAMStateForSurplus);

        return (stakingAMStateForAsset, stakingAMStateForPosition);
    }

    // forge-lint: disable-next-item(mixed-case-function,mixed-case-variable)
    function givenValidStakingAMState(StakingAMStateForSurplus memory stakingAMStateForSurplus) public view {
        // Given: The recipient is valid.
        _givenValidRecipient(stakingAMStateForSurplus.surplusRecipient);

        // And: The Asset Module holds its resting reward token balance.
        stakingAMStateForSurplus.lastRewardBalance =
            bound(stakingAMStateForSurplus.lastRewardBalance, 0, type(uint128).max);

        // And: The resting reward token balance covers the booked surplus (invariant).
        stakingAMStateForSurplus.bookedSurplus =
            bound(stakingAMStateForSurplus.bookedSurplus, 0, stakingAMStateForSurplus.lastRewardBalance);
    }

    // forge-lint: disable-next-item(mixed-case-function,mixed-case-variable)
    function currentRewardPerTokenGlobal(StakingAMStateForAsset memory stakingAMStateForAsset)
        public
        pure
        returns (uint128 rewardPerToken)
    {
        if (stakingAMStateForAsset.totalStaked == 0) return stakingAMStateForAsset.lastRewardPerTokenGlobal;

        uint256 deltaRewardPerToken =
            FullMath.mulDiv(stakingAMStateForAsset.currentRewardGlobal, 1e18, stakingAMStateForAsset.totalStaked);
        if (deltaRewardPerToken > type(uint128).max) deltaRewardPerToken = type(uint128).max;
        unchecked {
            rewardPerToken = stakingAMStateForAsset.lastRewardPerTokenGlobal + uint128(deltaRewardPerToken);
        }
    }

    function _credited(uint128 amountStaked, uint256 delivered) internal pure returns (uint256 credited) {
        StakingAMStateForAsset memory assetState;
        assetState.totalStaked = amountStaked;
        assetState.currentRewardGlobal = delivered;
        credited = uint256(currentRewardPerTokenGlobal(assetState)) * amountStaked / 1e18;
    }

    function _stakeSolePosition(address asset, uint128 amount) internal returns (uint256 positionId) {
        deal(asset, users.liquidityProvider, amount, true);
        vm.startPrank(users.liquidityProvider);
        ERC20Mock(asset).approve(address(stakingAM), amount);
        positionId = stakingAM.mint(asset, amount);
        vm.stopPrank();
    }

    function addAsset(uint8 assetDecimals) public returns (address asset_) {
        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        asset_ = address(new ERC20Mock("Asset", "AST", assetDecimals));
        stakingAM.addAsset(asset_);
    }
}
