/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

import { Emissions } from "./libraries/Emissions.sol";
import { IEmissionsHandler } from "./interfaces/IEmissionsHandler.sol";
import { IFactoryRegistry } from "./interfaces/IFactoryRegistry.sol";
import { ILeafVoter } from "./interfaces/ILeafVoter.sol";
import { IMetadex03CLGauge } from "./interfaces/IMetadex03CLGauge.sol";
import { IMetadex03CLGaugeFactory } from "./interfaces/IMetadex03CLGaugeFactory.sol";
import { IMetadex03CLPool } from "./interfaces/IMetadex03CLPool.sol";
import { IRegistry } from "../abstracts/AbstractDerivedAM.sol";
import { StakedSlipstreamAM } from "../Slipstream/StakedSlipstreamAM.sol";
import { Unused } from "../../libraries/Unused.sol";

/**
 * @title Asset Module for Staked Metadex03 Concentrated Liquidity Positions
 * @author Pragma Labs
 * @notice The pricing logic and basic information for Staked Metadex03 Concentrated Liquidity Positions.
 */
contract StakedMetadex03CLAM is StakedSlipstreamAM {
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
    IFactoryRegistry internal immutable FACTORY_REGISTRY;

    // The Metadex03 CL GaugeFactory.
    address public immutable GAUGE_FACTORY;

    // The Metadex03 LeafVoter.
    address public immutable LEAF_VOTER;

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param owner_ The address of the Owner.
     * @param registry The contract address of the Arcadia Registry.
     * @param gaugeFactory The contract address of the Metadex03 CL GaugeFactory.
     * @param rewardToken The contract address of the Reward Token.
     * @param surplusRecipient_ The recipient of every reward token that is not owed to a position.
     */
    constructor(address owner_, address registry, address gaugeFactory, address rewardToken, address surplusRecipient_)
        StakedSlipstreamAM(
            owner_,
            registry,
            IMetadex03CLGaugeFactory(gaugeFactory).nft(),
            Unused.IMMUTABLE,
            rewardToken,
            surplusRecipient_
        )
    {
        address leafVoter = IMetadex03CLGaugeFactory(gaugeFactory).leafVoter();
        (address rewardToken_, bool isRoot, address handler) = Emissions.resolve(leafVoter);
        if (rewardToken_ != rewardToken) revert RewardTokenNotValid();

        GAUGE_FACTORY = gaugeFactory;
        LEAF_VOTER = leafVoter;
        FACTORY_REGISTRY = IFactoryRegistry(ILeafVoter(leafVoter).FACTORY_REGISTRY());
        EMISSIONS_HANDLER = handler;

        // Only the root chain redeems on a claim, and defers a total below MIN_REDEEM_AMOUNT.
        IS_ROOT = isRoot;
        if (isRoot) MIN_REDEEM_AMOUNT = ILeafVoter(leafVoter).MIN_REDEEM_AMOUNT();
    }

    /**
     * @inheritdoc StakedSlipstreamAM
     */
    function _tokenName() internal pure override returns (string memory name_) {
        name_ = "Arcadia Staked Metadex03 CL Positions";
    }

    /**
     * @inheritdoc StakedSlipstreamAM
     */
    function _tokenSymbol() internal pure override returns (string memory symbol_) {
        symbol_ = "aSMDEXCLP";
    }

    /* ///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc StakedSlipstreamAM
     */
    function addGauge(address gauge) external override onlyOwner {
        if (FACTORY_REGISTRY.gaugeToFactory(gauge) != GAUGE_FACTORY) revert GaugeNotValid();

        address pool = FACTORY_REGISTRY.gaugeToTarget(gauge);
        if (IMetadex03CLPool(pool).gauge() != gauge) revert GaugeNotValid();

        if (!IRegistry(REGISTRY).isAllowed(IMetadex03CLPool(pool).token0(), 0)) revert AssetNotAllowed();
        if (!IRegistry(REGISTRY).isAllowed(IMetadex03CLPool(pool).token1(), 0)) revert AssetNotAllowed();

        poolToGauge[pool] = gauge;
    }

    /* ///////////////////////////////////////////////////////////////
                     INTERACTIONS STAKING CONTRACT
    /////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc StakedSlipstreamAM
     * @dev The gauge's earned() is already net of penalty and referral fees.
     */
    function rewardOf(uint256 positionId) public view override returns (uint256 rewards) {
        if (!Emissions.isMintable(LEAF_VOTER)) return 0;

        address gauge = positionState[positionId].gauge;
        // Cannot underflow.
        rewards = IMetadex03CLGauge(gauge).earned(address(this), _asSingleton(positionId))
            - IMetadex03CLGauge(gauge).deferredEmissions(address(this));
        if (rewards + _heldEmissions() < MIN_REDEEM_AMOUNT) return 0;
    }

    /**
     * @inheritdoc StakedSlipstreamAM
     */
    // forge-lint: disable-next-item(empty-block)
    function _rewardAmount(uint256) internal pure override returns (uint256) { }

    /**
     * @inheritdoc StakedSlipstreamAM
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _stake(address gauge, uint256 assetId) internal override {
        if (gauge == address(0)) revert GaugeNotValid();

        IMetadex03CLGauge(gauge).deposit(assetId);
    }

    /**
     * @inheritdoc StakedSlipstreamAM
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _withdrawAndClaim(address gauge, uint256 positionId) internal override returns (uint256 surplus) {
        uint256 pendingRedeems = _heldEmissions();
        IMetadex03CLGauge(gauge).withdraw(positionId);
        surplus = _getSurplus(pendingRedeems);
    }

    /**
     * @inheritdoc StakedSlipstreamAM
     * @dev Claims the deferred emissions first.
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _claimReward(address gauge, uint256 positionId) internal override returns (uint256 surplus) {
        uint256 pendingRedeems = _heldEmissions();
        _claimDeferred(gauge);
        IMetadex03CLGauge(gauge).claimEmissions(address(this), address(this), _asSingleton(positionId));
        surplus = _getSurplus(pendingRedeems);
    }

    /* ///////////////////////////////////////////////////////////////
                          EMERGENCY WITHDRAW
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Unstakes a staked Metadex03 Liquidity Position without claiming emissions.
     * @param positionId The id of the position.
     * @dev Only while the gauge factory enables emergency withdrawals. Forfeits the emissions accrued since the last claim.
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function emergencyBurn(uint256 positionId) external nonReentrant {
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        IMetadex03CLGauge(positionState[positionId].gauge).emergencyWithdraw(positionId);

        delete positionState[positionId];
        _burn(positionId);

        NON_FUNGIBLE_POSITION_MANAGER.safeTransferFrom(address(this), msg.sender, positionId);
    }

    /* ///////////////////////////////////////////////////////////////
                        DEFERRED EMISSIONS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Claims the emissions a gauge deferred to this contract, to the surplus recipient.
     * @param gauge The contract address of the gauge.
     * @dev On the root chain a sweep below MIN_REDEEM_AMOUNT is held and paid out once a later mint to the surplus recipient brings it to MIN_REDEEM_AMOUNT.
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function claimDeferredRewards(address gauge) external nonReentrant {
        if (FACTORY_REGISTRY.gaugeToFactory(gauge) != GAUGE_FACTORY) revert GaugeNotValid();

        _claimDeferred(gauge);
    }

    /**
     * @notice Claims the emissions a gauge deferred to this contract, to the surplus recipient.
     * @param gauge The contract address of the gauge.
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _claimDeferred(address gauge) internal {
        if (IMetadex03CLGauge(gauge).deferredEmissions(address(this)) == 0) return;

        IMetadex03CLGauge(gauge).claimEmissions(address(this), surplusRecipient, new uint256[](0));
    }

    /**
     * @notice Returns the amount the emissions handler holds for this contract before a claim.
     * @return pendingRedeems The amount the emissions handler holds for this contract.
     */
    function _heldEmissions() internal view returns (uint256 pendingRedeems) {
        if (IS_ROOT) pendingRedeems = IEmissionsHandler(EMISSIONS_HANDLER).pendingRedeems(address(this));
    }

    /**
     * @notice Returns the handler's hold a claim released.
     * @param pendingRedeems The amount the emissions handler held for this contract before the claim.
     * @return surplus The released amount, which is not owed to a position.
     * @dev The handler releases its hold in full or not at all.
     * @dev Emissions the gauge deferred on a withdraw while the chain could not mint go to the surplus recipient, not to the position.
     */
    function _getSurplus(uint256 pendingRedeems) internal view returns (uint256 surplus) {
        if (pendingRedeems == 0) return 0;
        if (IEmissionsHandler(EMISSIONS_HANDLER).pendingRedeems(address(this)) > 0) return 0;

        surplus = pendingRedeems;
    }

    /*///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Wraps a position id in a single element array.
     * @param positionId The id of the position.
     * @return positionIds The array with the single position id.
     */
    function _asSingleton(uint256 positionId) internal pure returns (uint256[] memory positionIds) {
        positionIds = new uint256[](1);
        positionIds[0] = positionId;
    }
}
