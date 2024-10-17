/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { DerivedAM, FixedPointMathLib, IRegistry } from "../abstracts/AbstractDerivedAM.sol";
import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC721 } from "../../../lib/solmate/src/tokens/ERC721.sol";
import { FixedPoint96 } from "../UniswapV3/libraries/FixedPoint96.sol";
import { IAeroVoter } from "../Aerodrome-Finance/interfaces/IAeroVoter.sol";
import { ICLGauge } from "./interfaces/ICLGauge.sol";
import { ICLPool } from "./interfaces/ICLPool.sol";
import { INonfungiblePositionManager } from "./interfaces/INonfungiblePositionManager.sol";
import { LiquidityAmounts } from "../UniswapV3/libraries/LiquidityAmounts.sol";
import { PoolAddress } from "./libraries/PoolAddress.sol";
import { ReentrancyGuard } from "../../../lib/solmate/src/utils/ReentrancyGuard.sol";
import { SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";
import { Strings } from "../../libraries/Strings.sol";
import { TickMath } from "../UniswapV3/libraries/TickMath.sol";

/**
 * @title Asset Module for Staked Slipstream Liquidity Positions
 * @author Pragma Labs
 * @notice The pricing logic and basic information for Staked Slipstream Liquidity Positions.
 * @dev The StakedSlipstreamAM will not price the underlying LP tokens via direct price oracles,
 * it will break down liquidity positions in the underlying tokens (ERC20s).
 * Only LP tokens for which the underlying tokens are allowed as collateral can be priced.
 */
contract StakedSlipstreamAM is DerivedAM, ERC721, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using Strings for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the Slipstream Factory.
    address internal immutable CL_FACTORY;

    // The Reward Token.
    ERC20 public immutable REWARD_TOKEN;

    // The Aerodrome voter contract.
    IAeroVoter internal immutable AERO_VOTER;

    // The contract address of the NonfungiblePositionManager.
    INonfungiblePositionManager internal immutable NON_FUNGIBLE_POSITION_MANAGER;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The baseURI of the ERC721 tokens.
    string public baseURI;

    // The unique identifiers of the Underlying Assets of a Liquidity Position.
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) public assetToUnderlyingAssets;

    // The allowed Gauges.
    mapping(address pool => address gauge) public poolToGauge;

    // Map a position id to its corresponding struct with the position state.
    mapping(uint256 position => PositionState) public positionState;

    // Struct with the Position specific state.
    struct PositionState {
        // The lower tick of the Liquidity Position.
        int24 tickLower;
        // The upper tick of the Liquidity Position.
        int24 tickUpper;
        // The liquidity of the Liquidity Position when it was deposited.
        uint128 liquidity;
        // The Slipstream Gauge.
        address gauge;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event RewardPaid(uint256 indexed positionId, address indexed reward, uint128 amount);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetNotAllowed();
    error GaugeNotValid();
    error InvalidId();
    error NotOwner();
    error RewardTokenNotAllowed();
    error RewardTokenNotValid();
    error ZeroLiquidity();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry The contract address of the Arcadia Registry.
     * @param nonFungiblePositionManager The contract address of the protocols NonFungiblePositionManager.
     * @param aerodromeVoter The contract address of the Aerodrome Finance Voter contract.
     * @param rewardToken The contract address of the Reward Token.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "2" for Slipstream Liquidity Positions (ERC721).
     */
    constructor(address registry, address nonFungiblePositionManager, address aerodromeVoter, address rewardToken)
        DerivedAM(registry, 2)
        ERC721("Arcadia Staked Slipstream Positions", "aSSLIPP")
    {
        if (!IRegistry(registry).isAllowed(rewardToken, 0)) revert RewardTokenNotAllowed();

        AERO_VOTER = IAeroVoter(aerodromeVoter);
        REWARD_TOKEN = ERC20(rewardToken);
        NON_FUNGIBLE_POSITION_MANAGER = INonfungiblePositionManager(nonFungiblePositionManager);
        CL_FACTORY = NON_FUNGIBLE_POSITION_MANAGER.factory();
    }

    /* //////////////////////////////////////////////////////////////
                               INITIALIZE
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function will add this contract as an asset in the Registry.
     * @dev Will revert if called more than once.
     */
    function initialize() external onlyOwner {
        inAssetModule[address(this)] = true;

        IRegistry(REGISTRY).addAsset(uint96(ASSET_TYPE), address(this));
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new Gauge to the StakedSlipstreamAM.
     * @param gauge The contract address of the gauge to stake Slipstream LP.
     * @dev Killed Gauges can be added, but no positions can be minted.
     */
    function addGauge(address gauge) external onlyOwner {
        if (AERO_VOTER.isGauge(gauge) != true) revert GaugeNotValid();
        if (ICLGauge(gauge).rewardToken() != address(REWARD_TOKEN)) revert RewardTokenNotValid();

        address pool = ICLGauge(gauge).pool();
        if (!IRegistry(REGISTRY).isAllowed(ICLPool(pool).token0(), 0)) revert AssetNotAllowed();
        if (!IRegistry(REGISTRY).isAllowed(ICLPool(pool).token1(), 0)) revert AssetNotAllowed();

        poolToGauge[pool] = gauge;
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool) {
        if (asset == address(this) && _ownerOf[assetId] != address(0)) return true;
        else return false;
    }

    /**
     * @notice Returns the unique identifiers of the Underlying Assets.
     * @param assetKey The unique identifier of the asset.
     * @return underlyingAssetKeys The unique identifiers of the Underlying Assets.
     */
    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        override
        returns (bytes32[] memory underlyingAssetKeys)
    {
        underlyingAssetKeys = assetToUnderlyingAssets[assetKey];
    }

    /**
     * @notice Calculates for a given asset the corresponding amount(s) of Underlying Asset(s).
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param amount The amount of the asset, in the decimal precision of the Asset.
     * @param underlyingAssetKeys The unique identifiers of the Underlying Assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 1e18 tokens of Underlying Asset, with 18 decimals precision.
     * @dev External price feeds of the Underlying Liquidity Position are used to calculate the flashloan resistant amounts.
     * This approach accommodates scenarios where an underlying asset could be
     * a derived asset itself (e.g., USDC/aUSDC pool), ensuring more versatile and accurate price calculations.
     */
    function _getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 amount,
        bytes32[] memory underlyingAssetKeys
    )
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        // Amount of a Staked Slipstream LP can only be either 0 or 1.
        if (amount == 0) {
            return (new uint256[](3), rateUnderlyingAssetsToUsd);
        }

        // Get the trusted rates to USD of the Underlying Assets.
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        // Calculate amount0 and amount1 of the principal (the actual liquidity position).
        // The liquidity of the Liquidity Position is stored in the Asset Module,
        // not fetched from the NonfungiblePositionManager.
        // Since liquidity of a position can be increased by a non-owner,
        // the max exposure checks for the principal of the position could otherwise be circumvented.
        (, uint256 assetId) = _getAssetFromKey(assetKey);
        underlyingAssetsAmounts = new uint256[](3);
        (underlyingAssetsAmounts[0], underlyingAssetsAmounts[1]) = _getPrincipalAmounts(
            positionState[assetId].tickLower,
            positionState[assetId].tickUpper,
            positionState[assetId].liquidity,
            rateUnderlyingAssetsToUsd[0].assetValue,
            rateUnderlyingAssetsToUsd[1].assetValue
        );

        // Get the staking rewards.
        underlyingAssetsAmounts[2] = rewardOf(assetId);
    }

    /**
     * @notice Calculates the underlying token amounts of a liquidity position, given external trusted prices.
     * @param tickLower The lower tick of the liquidity position.
     * @param tickUpper The upper tick of the liquidity position.
     * @param priceToken0 The price of 1e18 tokens of token0 in USD, with 18 decimals precision.
     * @param priceToken1 The price of 1e18 tokens of token1 in USD, with 18 decimals precision.
     * @return amount0 The amount of underlying token0 tokens.
     * @return amount1 The amount of underlying token1 tokens.
     */
    function _getPrincipalAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 priceToken0,
        uint256 priceToken1
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        // Calculate the square root of the relative rate sqrt(token1/token0) from the trusted USD price of both tokens.
        // sqrtPriceX96 is a binary fixed point number with 96 digits precision.
        uint160 sqrtPriceX96 = _getSqrtPriceX96(priceToken0, priceToken1);

        // Calculate amount0 and amount1 of the principal (the liquidity position without accumulated fees).
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
    }

    /**
     * @notice Calculates the sqrtPriceX96 (token1/token0) from trusted USD prices of both tokens.
     * @param priceToken0 The price of 1e18 tokens of token0 in USD, with 18 decimals precision.
     * @param priceToken1 The price of 1e18 tokens of token1 in USD, with 18 decimals precision.
     * @return sqrtPriceX96 The square root of the price (token1/token0), with 96 binary precision.
     * @dev The price in Slipstream is defined as:
     * price = amountToken1/amountToken0.
     * The usdPriceToken is defined as: usdPriceToken = amountUsd/amountToken.
     * => amountToken = amountUsd/usdPriceToken.
     * Hence we can derive the Slipstream price as:
     * price = (amountUsd/usdPriceToken1)/(amountUsd/usdPriceToken0) = usdPriceToken0/usdPriceToken1.
     */
    function _getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) internal pure returns (uint160 sqrtPriceX96) {
        if (priceToken1 == 0) return TickMath.MAX_SQRT_RATIO;

        // Both priceTokens have 18 decimals precision and result of division should have 28 decimals precision.
        // -> multiply by 1e28
        // priceXd28 will overflow if priceToken0 is greater than 1.158e+49.
        // For WBTC (which only has 8 decimals) this would require a bitcoin price greater than 115 792 089 237 316 198 989 824 USD/BTC.
        uint256 priceXd28 = priceToken0.mulDivDown(1e28, priceToken1);
        // Square root of a number with 28 decimals precision has 14 decimals precision.
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceXd28);

        // Change sqrtPrice from a decimal fixed point number with 14 digits to a binary fixed point number with 96 digits.
        // Unsafe cast: Cast will only overflow when priceToken0/priceToken1 >= 2^128.
        sqrtPriceX96 = uint160((sqrtPriceXd14 << FixedPoint96.RESOLUTION) / 1e14);
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk factors of an asset for a Creditor.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return collateralFactor The collateral factor of the asset for the Creditor, 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for the Creditor, 4 decimals precision.
     */
    function getRiskFactors(address creditor, address asset, uint256 assetId)
        external
        view
        override
        returns (uint16 collateralFactor, uint16 liquidationFactor)
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(assetKey);

        (uint256[] memory underlyingAssetsAmounts,) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, 1, underlyingAssetKeys);
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd =
            _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        (, uint256 collateralFactor_, uint256 liquidationFactor_) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);

        // Unsafe cast: collateralFactor_ and liquidationFactor_ are smaller than or equal to 1e4.
        return (uint16(collateralFactor_), uint16(liquidationFactor_));
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the USD value of an asset.
     * @param creditor The contract address of the Creditor.
     * @param underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @param rateUnderlyingAssetsToUsd The USD rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given Creditor, with 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given Creditor, with 4 decimals precision.
     * @dev We take the most conservative (lowest) risk factor of the principal assets of the Liquidity Position.
     * Next we take a USD-value weighted average of the risk factors of the principal and staking rewards.
     */
    function _calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) internal view override returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        // "rateUnderlyingAssetsToUsd" is the USD value with 18 decimals precision for 10**18 tokens of Underlying Asset.
        // To get the USD value (also with 18 decimals) of the actual amount of underlying assets, we have to multiply
        // the actual amount with the rate for 10**18 tokens, and divide by 10**18.
        uint256 valuePrincipal = underlyingAssetsAmounts[0].mulDivDown(rateUnderlyingAssetsToUsd[0].assetValue, 1e18)
            + underlyingAssetsAmounts[1].mulDivDown(rateUnderlyingAssetsToUsd[1].assetValue, 1e18);
        uint256 valueReward = underlyingAssetsAmounts[2].mulDivDown(rateUnderlyingAssetsToUsd[2].assetValue, 1e18);
        valueInUsd = valuePrincipal + valueReward;

        if (valueInUsd == 0) return (0, 0, 0);

        // Keep the lowest risk factor of the principal assets.
        collateralFactor = rateUnderlyingAssetsToUsd[0].collateralFactor < rateUnderlyingAssetsToUsd[1].collateralFactor
            ? rateUnderlyingAssetsToUsd[0].collateralFactor
            : rateUnderlyingAssetsToUsd[1].collateralFactor;
        liquidationFactor = rateUnderlyingAssetsToUsd[0].liquidationFactor
            < rateUnderlyingAssetsToUsd[1].liquidationFactor
            ? rateUnderlyingAssetsToUsd[0].liquidationFactor
            : rateUnderlyingAssetsToUsd[1].liquidationFactor;

        // Calculate weighted risk factors of principal and reward.
        unchecked {
            collateralFactor = (
                valuePrincipal * collateralFactor + valueReward * rateUnderlyingAssetsToUsd[2].collateralFactor
            ) / valueInUsd;
            liquidationFactor = (
                valuePrincipal * liquidationFactor + valueReward * rateUnderlyingAssetsToUsd[2].liquidationFactor
            ) / valueInUsd;
        }

        // Lower risk factors with the protocol wide risk factor.
        uint256 riskFactor = riskParams[creditor].riskFactor;
        collateralFactor = riskFactor.mulDivDown(collateralFactor, AssetValuationLib.ONE_4);
        liquidationFactor = riskFactor.mulDivDown(liquidationFactor, AssetValuationLib.ONE_4);
    }

    /*///////////////////////////////////////////////////////////////
                         STAKING MODULE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes a Slipstream Liquidity Position in its Gauge and mints a new position.
     * @param assetId The id of the Liquidity Position.
     * @return positionId The id of the Minted Position.
     * @dev the Minted Position has the same id as the Liquidity Position.
     */
    function mint(uint256 assetId) external nonReentrant returns (uint256 positionId) {
        if (assetId > type(uint96).max) revert InvalidId();
        NON_FUNGIBLE_POSITION_MANAGER.safeTransferFrom(msg.sender, address(this), assetId);

        // Get position.
        (,, address token0, address token1, int24 tickSpacing, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,)
        = NON_FUNGIBLE_POSITION_MANAGER.positions(assetId);
        if (liquidity == 0) revert ZeroLiquidity();

        // Get the Gauge.
        // If the gauge is not approved, poolToGauge will return the 0 address and deposit will revert.
        address gauge = poolToGauge[PoolAddress.computeAddress(CL_FACTORY, token0, token1, tickSpacing)];

        // Store the position state.
        positionState[assetId] =
            PositionState({ tickLower: tickLower, tickUpper: tickUpper, liquidity: liquidity, gauge: gauge });

        // Store underlying assets.
        bytes32[] memory underlyingAssetKeys = new bytes32[](3);
        underlyingAssetKeys[0] = _getKeyFromAsset(token0, 0);
        underlyingAssetKeys[1] = _getKeyFromAsset(token1, 0);
        underlyingAssetKeys[2] = _getKeyFromAsset(address(REWARD_TOKEN), 0);
        assetToUnderlyingAssets[_getKeyFromAsset(address(this), assetId)] = underlyingAssetKeys;

        // Stake the Liquidity Position.
        NON_FUNGIBLE_POSITION_MANAGER.approve(gauge, assetId);
        ICLGauge(gauge).deposit(assetId);

        // If the Liquidity Position already collected fees,
        // these were claimed during the deposit and send to this contract.
        uint256 balance0 = ERC20(token0).balanceOf(address(this));
        uint256 balance1 = ERC20(token1).balanceOf(address(this));
        if (balance0 > 0) ERC20(token0).safeTransfer(msg.sender, balance0);
        if (balance1 > 0) ERC20(token1).safeTransfer(msg.sender, balance1);

        // Mint the new position, with same id as the underlying position.
        positionId = assetId;
        _safeMint(msg.sender, positionId);
    }

    /**
     * @notice Unstakes a staked Slipstream Liquidity Position and claims rewards.
     * @param positionId The id of the position.
     * @return rewards The amount of reward tokens claimed.
     */
    function burn(uint256 positionId) external nonReentrant returns (uint256 rewards) {
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Unstake the Liquidity Position.
        ICLGauge(positionState[positionId].gauge).withdraw(positionId);
        rewards = REWARD_TOKEN.balanceOf(address(this));

        // Burn the position.
        delete positionState[positionId];
        _burn(positionId);

        // Pay out the rewards to the position owner.
        if (rewards > 0) {
            // Transfer reward
            REWARD_TOKEN.safeTransfer(msg.sender, rewards);
            emit RewardPaid(positionId, address(REWARD_TOKEN), uint128(rewards));
        }

        // Transfer the asset back to the position owner.
        NON_FUNGIBLE_POSITION_MANAGER.safeTransferFrom(address(this), msg.sender, positionId);
    }

    /**
     * @notice Claims and transfers the staking rewards of the position.
     * @param positionId The id of the position.
     * @return rewards The amount of reward tokens claimed.
     */
    function claimReward(uint256 positionId) external nonReentrant returns (uint256 rewards) {
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Claim the rewards from the external staking contract.
        ICLGauge(positionState[positionId].gauge).getReward(positionId);
        rewards = REWARD_TOKEN.balanceOf(address(this));

        // Pay out the rewards to the position owner.
        if (rewards > 0) {
            // Transfer reward
            REWARD_TOKEN.safeTransfer(msg.sender, rewards);
            emit RewardPaid(positionId, address(REWARD_TOKEN), uint128(rewards));
        }
    }

    /**
     * @notice Returns the amount of reward tokens claimable by a position.
     * @param positionId The id of the position to check the rewards for.
     * @return rewards The current amount of reward tokens claimable by the owner of the position.
     */
    function rewardOf(uint256 positionId) public view returns (uint256 rewards) {
        rewards = ICLGauge(positionState[positionId].gauge).earned(address(this), positionId);
    }

    /*///////////////////////////////////////////////////////////////
                        ERC-721 LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function that stores a new base URI.
     * @param newBaseURI The new base URI to store.
     */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    /**
     * @notice Function that returns the token URI as defined in the ERC721 standard.
     * @param tokenId The id of the Account.
     * @return uri The token URI.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @notice Returns the onERC721Received selector.
     */
    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
