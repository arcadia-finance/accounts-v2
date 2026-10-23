/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test } from "../AbstractStakingAM/_AbstractStakingAM.fuzz.t.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { IMetadex03V2Gauge } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Gauge.sol";
import { IMetadex03V2Pool } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Pool.sol";
import { Metadex03Fixture } from "../../../utils/fixtures/metadex03/Metadex03Fixture.f.sol";
import { Metadex03PoolAM } from "../../../../src/asset-modules/Metadex03/Metadex03PoolAM.sol";
import { StakedMetadex03AMExtension } from "../../../utils/extensions/StakedMetadex03AMExtension.sol";
import { StakingAM } from "../../../../src/asset-modules/abstracts/AbstractStakingAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Common logic needed by "StakedMetadex03AM" fuzz tests.
 */
// forge-lint: disable-next-item(reentrancy-no-eth)
abstract contract StakedMetadex03AM_Fuzz_Test is Fuzz_Test, AbstractStakingAM_Fuzz_Test, Metadex03Fixture {
    using stdStorage for StdStorage;

    /*////////////////////////////////////////////////////////////////
                                STRUCTS
    /////////////////////////////////////////////////////////////// */

    struct GaugeState {
        uint128 stake;
        uint256 emissions;
    }

    /*////////////////////////////////////////////////////////////////
                               CONSTANTS
    /////////////////////////////////////////////////////////////// */

    // The wei the gauge's floor divisions can round off an accrual.
    uint256 internal constant GAUGE_ROUNDING_WEI = 2;

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-start(mixed-case-variable)
    address internal surplusRecipient;
    Metadex03PoolAM internal metadex03PoolAM;
    IMetadex03V2Gauge internal metadex03Gauge;
    IMetadex03V2Pool internal metadex03Pool;
    StakedMetadex03AMExtension internal stakedMetadex03AM;
    // forge-lint: disable-end(mixed-case-variable)

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, AbstractStakingAM_Fuzz_Test) {
        Fuzz_Test.setUp();

        surplusRecipient = users.treasury;
        _stageMetadex03(false);
    }

    // Stages Metadex03 on the root or a leaf chain.
    function _stageMetadex03(bool root) internal {
        deployMetadex03Periphery(root);
        deployMetadex03();

        rewardToken = ERC20Mock(root ? rootToken : receiptToken);
        // forge-lint: disable-next-item(unsafe-typecast)
        addAssetToArcadia(address(rewardToken), int256(rates.token1ToUsd));

        vm.startPrank(users.owner);
        metadex03PoolAM = new Metadex03PoolAM(
            users.owner, address(registry), address(stablePoolFactory), address(volatilePoolFactory)
        );
        registry.addAssetModule(address(metadex03PoolAM));

        stakedMetadex03AM = new StakedMetadex03AMExtension(
            users.owner,
            address(registry),
            address(metadex03StableGaugeFactory),
            address(metadex03GaugeFactory),
            surplusRecipient
        );
        registry.addAssetModule(address(stakedMetadex03AM));
        stakedMetadex03AM.initialize();
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-next-item(mixed-case-function,mixed-case-variable,unsafe-typecast)
    function givenValidStakingAMStateMetadex03(
        StakingAMStateForAsset memory stakingAMStateForAsset,
        StakingAM.PositionState memory stakingAMStateForPosition,
        StakingAMStateForSurplus memory stakingAMStateForSurplus
    ) internal view {
        stakingAMStateForAsset.totalStaked = uint128(bound(stakingAMStateForAsset.totalStaked, 1, type(uint128).max));
        stakingAMStateForPosition.amountStaked =
            uint128(bound(stakingAMStateForPosition.amountStaked, 1, stakingAMStateForAsset.totalStaked));
        stakingAMStateForAsset.currentRewardGlobal =
            bound(stakingAMStateForAsset.currentRewardGlobal, 0, type(uint128).max);
        givenValidStakingAMState(stakingAMStateForSurplus);
    }

    function _givenSurplusRecipient(address recipient) internal {
        _givenValidRecipient(recipient);

        surplusRecipient = recipient;
        vm.prank(users.owner);
        stakedMetadex03AM.setSurplusRecipient(recipient);
    }

    // forge-lint: disable-next-item(mixed-case-function,mixed-case-variable)
    function setStakedMetadex03AMState(StakingAMStateForSurplus memory stakingAMStateForSurplus) internal {
        deal(address(rewardToken), address(stakedMetadex03AM), stakingAMStateForSurplus.lastRewardBalance);
        stakedMetadex03AM.setLastRewardBalance(stakingAMStateForSurplus.lastRewardBalance);
        stakedMetadex03AM.setBookedSurplus(stakingAMStateForSurplus.bookedSurplus);
        surplusRecipient = stakingAMStateForSurplus.surplusRecipient;
        vm.prank(users.owner);
        stakedMetadex03AM.setSurplusRecipient(stakingAMStateForSurplus.surplusRecipient);
    }

    // forge-lint: disable-next-item(mixed-case-function,mixed-case-variable)
    function setStakedMetadex03AMState(
        StakingAMStateForAsset memory stakingAMStateForAsset,
        StakingAM.PositionState memory stakingAMStateForPosition,
        StakingAMStateForSurplus memory stakingAMStateForSurplus,
        address asset,
        uint96 id
    ) internal {
        stakedMetadex03AM.setTotalStaked(asset, stakingAMStateForAsset.totalStaked);
        stakedMetadex03AM.setLastRewardPerTokenPosition(id, stakingAMStateForPosition.lastRewardPerTokenPosition);
        stakedMetadex03AM.setLastRewardPerTokenGlobal(asset, stakingAMStateForAsset.lastRewardPerTokenGlobal);

        deal(asset, address(stakedMetadex03AM), stakingAMStateForPosition.amountStaked, true);
        stakedMetadex03AM.stakeAndClaim(id, asset, stakingAMStateForPosition.amountStaked);
        stakedMetadex03AM.setLastPositionId(id);

        if (stakingAMStateForAsset.currentRewardGlobal > 0) {
            addEmissionsToGauge(address(metadex03Gauge), stakingAMStateForAsset.currentRewardGlobal);
            // Use the gauge's floored reward.
            stakingAMStateForAsset.currentRewardGlobal = metadex03Gauge.earned(stakedMetadex03AM.getStaker(id));
        }

        // Re-cap lastRewardPosition against the reward the gauge reports.
        // forge-lint: disable-next-item(unsafe-typecast)
        stakingAMStateForPosition.lastRewardPosition = uint128(
            bound(
                stakingAMStateForPosition.lastRewardPosition,
                0,
                type(uint128).max - stakingAMStateForAsset.currentRewardGlobal
            )
        );
        stakedMetadex03AM.setLastRewardPosition(id, stakingAMStateForPosition.lastRewardPosition);
        stakedMetadex03AM.setAmountStakedForPosition(id, stakingAMStateForPosition.amountStaked);
        stakingAMStateForPosition.asset = asset;
        stakedMetadex03AM.setAssetInPosition(asset, id);

        setStakedMetadex03AMState(stakingAMStateForSurplus);

        uint256 rewardBalance =
            stakingAMStateForSurplus.lastRewardBalance + stakingAMStateForPosition.lastRewardPosition;
        deal(address(rewardToken), address(stakedMetadex03AM), rewardBalance);
        stakedMetadex03AM.setLastRewardBalance(rewardBalance);
    }

    function givenValidGaugeState(GaugeState memory gaugeState, uint256 stakedByModule) internal pure {
        // forge-lint: disable-next-item(unsafe-typecast)
        gaugeState.stake = uint128(bound(gaugeState.stake, stakedByModule * 4e6, type(uint128).max));
        gaugeState.emissions = bound(
            gaugeState.emissions,
            MIN_REDEEM_AMOUNT + uint256(gaugeState.stake) / PRECISION + GAUGE_ROUNDING_WEI,
            MAX_BASE_RATE / 4
        );
    }

    function assertSolvent(uint256[] memory positionIds) internal view {
        uint256 credited;
        for (uint256 i; i < positionIds.length; ++i) {
            (,,, uint128 lastRewardPosition) = stakedMetadex03AM.positionState(positionIds[i]);
            credited += lastRewardPosition;
        }
        assertGe(
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)),
            credited + stakedMetadex03AM.claimableSurplus()
        );
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _addGauge() internal {
        metadex03Pool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        metadex03Gauge = createGaugeMetadex03(address(metadex03Pool));
        stakedMetadex03AM.addAsset(address(metadex03Gauge));
    }

    function _addGaugeWithPenalty(uint256 minStakeBlocks, uint256 penaltyRate) internal {
        _addGauge();

        // Activate the penalty config.
        setPenaltyConfig(address(metadex03Gauge), minStakeBlocks, penaltyRate);
    }

    function _stakeInGauge(uint256 lpBalance) internal returns (uint256 staked, uint256 positionId) {
        _addGauge();
        (staked, positionId) = _dealAndStake(address(metadex03Pool), lpBalance);
    }

    function _stakeInGaugeWithPenalty(uint256 lpBalance, uint256 minStakeBlocks, uint256 penaltyRate)
        internal
        returns (uint256 staked, uint256 positionId)
    {
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);
        (staked, positionId) = _dealAndStake(address(metadex03Pool), lpBalance);
    }

    function _dealAndStake(address pool, uint256 lpBalance) internal returns (uint256 staked, uint256 positionId) {
        // The Asset Module never stakes more than a uint128.
        staked = bound(lpBalance, 1, type(uint128).max);

        positionId = stakedMetadex03AM.getLastPositionId() + 1;
        deal(pool, address(stakedMetadex03AM), staked);
        stakedMetadex03AM.stakeAndClaim(positionId, pool, staked);
        stakedMetadex03AM.setLastPositionId(positionId);
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _mintPosition(address account, uint128 amount) internal returns (uint256 positionId) {
        deal(address(metadex03Pool), account, amount);
        vm.startPrank(account);
        metadex03Pool.approve(address(stakedMetadex03AM), amount);
        positionId = stakedMetadex03AM.mint(address(metadex03Pool), amount);
        vm.stopPrank();
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _increasePosition(address account, uint256 positionId, uint128 amount) internal {
        deal(address(metadex03Pool), account, amount);
        vm.startPrank(account);
        metadex03Pool.approve(address(stakedMetadex03AM), amount);
        stakedMetadex03AM.increaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function _initPositionWithEarned(uint128 amount, uint256 emissions) internal returns (uint256 positionId) {
        _addGauge();
        positionId = _mintPosition(users.accountOwner, amount);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _initBurnedDeferredAndLivePosition(
        uint128 amount,
        uint256 emissions,
        uint128 amountOther,
        uint256 emissionsOther
    ) internal returns (uint256 positionId, uint256 positionIdOther) {
        positionId = _initPositionWithEarned(amount, emissions);
        positionIdOther = _mintPosition(users.liquidityProvider, amountOther);

        setChainSuspended(true);
        vm.prank(users.accountOwner);
        stakedMetadex03AM.decreaseLiquidity(positionId, amount);
        setChainSuspended(false);

        addEmissionsToGauge(address(metadex03Gauge), emissionsOther);
    }

    function _initHeldDeferredRewards(uint128 amount, uint256 emissions, uint256 withdrawAmount)
        internal
        returns (uint256 positionId, uint256 deferredEmissions)
    {
        (positionId, deferredEmissions) = _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);

        vm.prank(users.accountOwner);
        stakedMetadex03AM.claimReward(positionId);
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _initPositionWithDeferredRewards(uint128 amount, uint256 emissions, uint256 withdrawAmount)
        internal
        returns (uint256 positionId, uint256 deferredRewards)
    {
        positionId = _initPositionWithEarned(amount, emissions);
        deferredRewards = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));

        // forge-lint: disable-next-item(unsafe-typecast)
        uint128 withdrawn = uint128(bound(withdrawAmount, 1, amount - 1));
        setChainSuspended(true);
        vm.prank(users.accountOwner);
        stakedMetadex03AM.decreaseLiquidity(positionId, withdrawn);
        setChainSuspended(false);
    }
}
