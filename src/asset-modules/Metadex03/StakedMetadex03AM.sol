/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

import { AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { ERC20, IRegistry, StakingAM } from "../abstracts/AbstractStakingAM.sol";
import { Emissions } from "./libraries/Emissions.sol";
import { IEmissionsHandler } from "./interfaces/IEmissionsHandler.sol";
import { IFactoryRegistry } from "./interfaces/IFactoryRegistry.sol";
import { IGaugeFactory } from "./interfaces/IGaugeFactory.sol";
import { ILeafVoter } from "./interfaces/ILeafVoter.sol";
import { IMetadex03Gauge } from "./interfaces/IMetadex03Gauge.sol";
import { LibClone } from "../../../lib/solady/src/utils/LibClone.sol";
import { Metadex03Staker } from "./Metadex03Staker.sol";
import { PenaltyWindows } from "./libraries/PenaltyWindows.sol";
import { SafeCastLib } from "../../../lib/solmate/src/utils/SafeCastLib.sol";
import { SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title Asset Module for Staked Metadex03 pools
 * @author Pragma Labs
 * @notice The pricing logic and basic information for Staked Metadex03 LP pools.
 * @dev The reward asset is the token the chain's emissions handler delivers.
 * @dev Every position stakes through its own Metadex03 Staker, so each position has its own depositBlock.
 */
contract StakedMetadex03AM is StakingAM {
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The root chain redeems the ReceiptToken for the Token on a claim, a leaf chain pays out the ReceiptToken.
    bool public immutable IS_ROOT;

    // The minimum amount the root chain's emissions handler redeems, zero on a leaf chain.
    uint256 public immutable MIN_REDEEM_AMOUNT;

    // The Metadex03 emissions handler of the chain.
    address public immutable EMISSIONS_HANDLER;

    // The Metadex03 FactoryRegistry.
    IFactoryRegistry public immutable FACTORY_REGISTRY;

    // The Metadex03 LeafVoter.
    address public immutable LEAF_VOTER;

    // The GaugeFactory of the stable pools.
    address public immutable STABLE_GAUGE_FACTORY;

    // The Metadex03 Staker implementation of the position clones.
    address public immutable STAKER;

    // The GaugeFactory of the volatile pools.
    address public immutable VOLATILE_GAUGE_FACTORY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Maps a Metadex03 Pool to its gauge.
    mapping(address asset => address gauge) public assetToGauge;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetAlreadySet();
    error GaugeFactoryNotValid();
    error GaugeNotValid();
    error PenaltyWindowOpen();
    error PoolNotAllowed();
    error PositionNotBurned();
    error RewardTokenNotAllowed();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param owner_ The address of the Owner.
     * @param registry The address of the Registry.
     * @param stableGaugeFactory The address of the Metadex03 GaugeFactory of the stable pools.
     * @param volatileGaugeFactory The address of the Metadex03 GaugeFactory of the volatile pools.
     * @param surplusRecipient_ The recipient of every reward token that is not owed to a position.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "2" for ERC721 tokens.
     */
    constructor(
        address owner_,
        address registry,
        address stableGaugeFactory,
        address volatileGaugeFactory,
        address surplusRecipient_
    ) StakingAM(owner_, registry, "Arcadia Staked Metadex03 Positions", "aSMDEXP", surplusRecipient_) {
        if (!IGaugeFactory(stableGaugeFactory).IS_STABLE()) revert GaugeFactoryNotValid();
        if (IGaugeFactory(volatileGaugeFactory).IS_STABLE()) revert GaugeFactoryNotValid();

        address leafVoter = IGaugeFactory(stableGaugeFactory).LEAF_VOTER();
        if (IGaugeFactory(volatileGaugeFactory).LEAF_VOTER() != leafVoter) revert GaugeFactoryNotValid();

        STABLE_GAUGE_FACTORY = stableGaugeFactory;
        VOLATILE_GAUGE_FACTORY = volatileGaugeFactory;
        STAKER = address(new Metadex03Staker());
        LEAF_VOTER = leafVoter;
        FACTORY_REGISTRY = IFactoryRegistry(ILeafVoter(leafVoter).FACTORY_REGISTRY());
        (address rewardToken, bool isRoot, address handler) = Emissions.resolve(leafVoter);
        REWARD_TOKEN = ERC20(rewardToken);
        EMISSIONS_HANDLER = handler;

        // Only the root chain redeems on a claim, and defers a total below MIN_REDEEM_AMOUNT.
        IS_ROOT = isRoot;
        if (isRoot) MIN_REDEEM_AMOUNT = ILeafVoter(leafVoter).MIN_REDEEM_AMOUNT();
    }

    /* //////////////////////////////////////////////////////////////
                               INITIALIZE
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function will add this contract as an asset in the Registry.
     * @dev Will revert if called more than once.
     */
    function initialize() public override onlyOwner {
        if (!IRegistry(REGISTRY).isAllowed(address(REWARD_TOKEN), 0)) revert RewardTokenNotAllowed();

        super.initialize();
    }

    /*///////////////////////////////////////////////////////////////
                            ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new Staked Metadex03 pool to the StakedMetadex03AM.
     * @param gauge The contract address of the gauge to stake the Metadex03 LP.
     */
    function addAsset(address gauge) external {
        address pool = IMetadex03Gauge(gauge).stakingToken();
        if (FACTORY_REGISTRY.gaugeToTarget(gauge) != pool) revert GaugeNotValid();

        address gaugeFactory = FACTORY_REGISTRY.gaugeToFactory(gauge);
        if (gaugeFactory != STABLE_GAUGE_FACTORY && gaugeFactory != VOLATILE_GAUGE_FACTORY) revert GaugeNotValid();

        if (!IRegistry(REGISTRY).isAllowed(pool, 0)) revert PoolNotAllowed();
        if (assetState[pool].allowed) revert AssetAlreadySet();

        assetToGauge[pool] = gauge;
        _addAsset(pool);
    }

    /*///////////////////////////////////////////////////////////////
                          ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc StakingAM
     */
    function _getUnderlyingAssetsAmounts(address, bytes32 assetKey, uint256 amount, bytes32[] memory)
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        if (amount == 0) return (new uint256[](2), rateUnderlyingAssetsToUsd);

        (, uint256 positionId) = _getAssetFromKey(assetKey);

        underlyingAssetsAmounts = new uint256[](2);
        underlyingAssetsAmounts[0] = positionState[positionId].amountStaked;
    }

    /*///////////////////////////////////////////////////////////////
                     INTERACTIONS STAKING CONTRACT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of tokens in the external staking contract.
     * @param positionId The id of the position.
     * @param asset The contract address of the Asset to stake.
     * @param amount The amount of Asset to stake.
     * @return surplus The claimed amount that is not owed to a position.
     * @dev The claim MUST happen before the deposit.
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _stakeAndClaim(uint256 positionId, address asset, uint256 amount)
        internal
        override
        returns (uint256 surplus)
    {
        address gauge = assetToGauge[asset];
        address staker = getStaker(positionId);
        if (staker.code.length == 0) {
            LibClone.cloneDeterministic(STAKER, bytes32(positionId));
            Metadex03Staker(staker).initialize(gauge, asset);
        } else {
            surplus = _claimReward(positionId, asset);
        }

        // forge-lint: disable-next-item(solmate-safe-transfer-lib)
        ERC20(asset).safeTransfer(staker, amount);
        Metadex03Staker(staker).deposit(gauge, amount);
    }

    /**
     * @notice Unstakes and withdraws the Asset from the external contract.
     * @param positionId The id of the position.
     * @param asset The contract address of the Asset to unstake and withdraw.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     * @return surplus The claimed amount that is not owed to a position.
     * @dev The gauge claims the emissions to the caller before releasing the stake.
     * @dev Withdrawals are not blocked during the Penalty Window.
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _withdrawAndClaim(uint256 positionId, address asset, uint256 amount)
        internal
        override
        returns (uint256 surplus)
    {
        address gauge = assetToGauge[asset];
        address staker = getStaker(positionId);
        (uint256 deferredEmissions, uint256 pendingRedeems) = _heldEmissions(gauge, staker);
        IMetadex03Gauge(gauge).withdrawFrom(amount, staker);
        surplus = _getSurplus(gauge, staker, deferredEmissions, pendingRedeems);
    }

    /**
     * @notice Claims the rewards available for a position.
     * @param positionId The id of the position.
     * @param asset The contract address of the Asset to claim the rewards for.
     * @return surplus The claimed amount that is not owed to a position.
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _claimReward(uint256 positionId, address asset) internal override returns (uint256 surplus) {
        address gauge = assetToGauge[asset];
        address staker = getStaker(positionId);
        if (PenaltyWindows.isOpen(gauge, staker)) revert PenaltyWindowOpen();

        (uint256 deferredEmissions, uint256 pendingRedeems) = _heldEmissions(gauge, staker);
        IMetadex03Gauge(gauge).claimEmissions(staker, address(this));
        surplus = _getSurplus(gauge, staker, deferredEmissions, pendingRedeems);
    }

    /**
     * @notice Returns the amount of reward tokens that can be claimed for a position.
     * @param positionId The id of the position.
     * @param asset The Asset to get the current rewards for.
     * @return currentReward The amount of reward tokens that can be claimed.
     * @dev The gauge's earned() is already net of penalty and referral fees.
     */
    function _getCurrentReward(uint256 positionId, address asset)
        internal
        view
        override
        returns (uint256 currentReward)
    {
        if (!Emissions.isMintable(LEAF_VOTER)) return 0;

        address gauge = assetToGauge[asset];
        address staker = getStaker(positionId);
        (uint256 deferredEmissions, uint256 pendingRedeems) = _heldEmissions(gauge, staker);
        currentReward = IMetadex03Gauge(gauge).earned(staker);
        if (currentReward + pendingRedeems < MIN_REDEEM_AMOUNT) return 0;

        // Cannot underflow.
        currentReward -= deferredEmissions;
    }

    /**
     * @notice Returns the Metadex03 Staker of a position.
     * @param positionId The id of the position.
     * @return staker The contract address of the Metadex03 Staker.
     */
    function getStaker(uint256 positionId) public view returns (address staker) {
        staker = LibClone.predictDeterministicAddress(STAKER, bytes32(positionId), address(this));
    }

    /*///////////////////////////////////////////////////////////////
                         REWARDS VIEW FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Credits the rewards claimed by the staker of a position to that position.
     * @param assetState_ Struct with the old rewards state of the Asset.
     * @param positionState_ Struct with the old rewards state of the position.
     * @param currentReward The amount of reward tokens claimed by the staker of the position.
     * @return currentAssetState Struct with the current rewards state of the Asset.
     * @return currentPositionState Struct with the current rewards state of the position.
     */
    function _getRewardBalances(
        AssetState memory assetState_,
        PositionState memory positionState_,
        uint256 currentReward
    ) internal pure override returns (AssetState memory, PositionState memory) {
        positionState_.lastRewardPosition = SafeCastLib.safeCastTo128(positionState_.lastRewardPosition + currentReward);

        return (assetState_, positionState_);
    }

    /*///////////////////////////////////////////////////////////////
                          EMERGENCY WITHDRAW
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Unstakes and withdraws the total amount staked of a position without claiming emissions.
     * @param positionId The id of the position to burn.
     * @return rewards The amount of reward tokens paid out.
     * @dev Only while the gauge factory enables emergency withdrawals. Forfeits the emissions accrued since the last claim.
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function emergencyBurn(uint256 positionId) external nonReentrant returns (uint256 rewards) {
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        PositionState memory positionState_ = positionState[positionId];
        address asset = positionState_.asset;
        uint128 amount = positionState_.amountStaked;

        uint256 rewardBalance = REWARD_TOKEN.balanceOf(address(this));
        bookedSurplus += rewardBalance - lastRewardBalance;
        Metadex03Staker(getStaker(positionId)).emergencyWithdraw(assetToGauge[asset], asset, amount);

        assetState[asset].totalStaked -= amount;
        rewards = positionState_.lastRewardPosition;
        delete positionState[positionId];
        _burn(positionId);

        if (rewards > 0) {
            // forge-lint: disable-next-item(solmate-safe-transfer-lib)
            REWARD_TOKEN.safeTransfer(msg.sender, rewards);
            // forge-lint: disable-next-line(unsafe-typecast)
            emit RewardPaid(positionId, address(REWARD_TOKEN), uint128(rewards));
        }
        lastRewardBalance = rewardBalance - rewards;

        // forge-lint: disable-next-item(solmate-safe-transfer-lib)
        ERC20(asset).safeTransfer(msg.sender, amount);
        emit LiquidityDecreased(positionId, asset, amount);
    }

    /*///////////////////////////////////////////////////////////////
                        DEFERRED EMISSIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Claims the emissions a gauge deferred to the staker of a burned position, to the surplus recipient.
     * @param gauge The contract address of the gauge.
     * @param positionId The id of the position.
     * @dev On the root chain a sweep below MIN_REDEEM_AMOUNT is held and paid out once a later mint to the surplus recipient brings it to MIN_REDEEM_AMOUNT.
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function claimDeferredRewards(address gauge, uint256 positionId) external nonReentrant {
        if (assetToGauge[FACTORY_REGISTRY.gaugeToTarget(gauge)] != gauge) revert GaugeNotValid();
        if (_ownerOf[positionId] != address(0)) revert PositionNotBurned();

        address staker = getStaker(positionId);
        if (IMetadex03Gauge(gauge).deferredEmissions(staker) == 0) return;

        IMetadex03Gauge(gauge).claimEmissions(staker, surplusRecipient);
    }

    /**
     * @notice Returns the emissions the gauge and the emissions handler hold for a staker before a claim.
     * @param gauge The contract address of the gauge.
     * @param staker The contract address of the Metadex03 Staker.
     * @return deferredEmissions The emissions the gauge defers to the staker.
     * @return pendingRedeems The amount the emissions handler holds for this contract.
     */
    function _heldEmissions(address gauge, address staker)
        internal
        view
        returns (uint256 deferredEmissions, uint256 pendingRedeems)
    {
        deferredEmissions = IMetadex03Gauge(gauge).deferredEmissions(staker);
        if (IS_ROOT) pendingRedeems = IEmissionsHandler(EMISSIONS_HANDLER).pendingRedeems(address(this));
    }

    /**
     * @notice Returns the deferred emissions and the handler's hold a claim released.
     * @param gauge The contract address of the gauge.
     * @param staker The contract address of the Metadex03 Staker.
     * @param deferredEmissions The emissions the gauge deferred to the staker before the claim.
     * @param pendingRedeems The amount the emissions handler held for this contract before the claim.
     * @return surplus The released amount, which is not owed to a position.
     * @dev The gauge clears its deferred emissions in full or not at all, the handler releases its hold in full or not at all.
     * @dev Emissions the gauge deferred on a withdraw while the chain could not mint go to the surplus recipient, not to the position.
     */
    function _getSurplus(address gauge, address staker, uint256 deferredEmissions, uint256 pendingRedeems)
        internal
        view
        returns (uint256 surplus)
    {
        if (IS_ROOT && IEmissionsHandler(EMISSIONS_HANDLER).pendingRedeems(address(this)) > 0) return 0;
        if (IMetadex03Gauge(gauge).deferredEmissions(staker) > 0) deferredEmissions = 0;

        surplus = deferredEmissions + pendingRedeems;
    }
}
