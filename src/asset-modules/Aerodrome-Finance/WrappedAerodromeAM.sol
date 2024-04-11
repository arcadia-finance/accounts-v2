/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { DerivedAM, FixedPointMathLib, IRegistry } from "../abstracts/AbstractDerivedAM.sol";
import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC721 } from "../../../lib/solmate/src/tokens/ERC721.sol";
import { IAeroPool } from "./interfaces/IAeroPool.sol";
import { ReentrancyGuard } from "../../../lib/solmate/src/utils/ReentrancyGuard.sol";
import { SafeCastLib } from "../../../lib/solmate/src/utils/SafeCastLib.sol";
import { SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";
import { Strings } from "../../libraries/Strings.sol";

/**
 * @title Asset Module for Wrapped Aerodrome Finance pools
 * @author Pragma Labs
 * @notice The Wrapped Aerodrome Finance Asset Module stores pricing logic and basic information for Wrapped Aerodrome Finance Pools.
 */
contract WrappedAerodromeAM is DerivedAM, ERC721, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using Strings for uint256;
    using SafeCastLib for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The id of last minted position.
    uint256 internal lastPositionId;

    // The baseURI of the ERC721 tokens.
    string public baseURI;

    // Map a Pool to its corresponding token0.
    mapping(address pool => address token0) public token0;
    // Map a Pool to its corresponding token1.
    mapping(address pool => address token1) public token1;
    // Map a Pool to its corresponding struct with global state.
    mapping(address pool => PoolState) public poolState;
    // Map a position id to its corresponding struct with the position state.
    mapping(uint256 position => PositionState) public positionState;

    // Struct with the global state per Pool.
    struct PoolState {
        // The growth of fees per Pool, at the last interaction with this contract,
        // with 18 decimals precision.
        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        // The total amount of liquidity wrapped.
        uint128 totalWrapped;
    }

    // Struct with the Position specific state.
    struct PositionState {
        // The growth of fees per Pool, at the last interaction of the position owner with this contract,
        // with 18 decimals precision.
        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        // The unclaimed amount of fees of the position owner, at the last interaction of the owner with this contract.
        uint128 fee0;
        uint128 fee1;
        // Total amount of liquidity wrapped for this position.
        uint128 amountWrapped;
        // The contract address of the Pool.
        address pool;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event LiquidityDecreased(uint256 indexed positionId, address indexed pool, uint128 amount);
    event LiquidityIncreased(uint256 indexed positionId, address indexed pool, uint128 amount);
    event FeesPaid(uint256 indexed positionId, uint128 fee0, uint128 fee1);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error NotOwner();
    error PoolNotAllowed();
    error ZeroAmount();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry The address of the Registry.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "2" for ERC721 tokens.
     */
    constructor(address registry) DerivedAM(registry, 2) ERC721("Arcadia Wrapped Aerodrome Positions", "aWAEROP") { }

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
     * @notice Adds a new Aerodrome Finance pool to the WrappedAerodromeAM.
     * @param pool The contract address of the Aerodrome Finance pool.
     */
    function addAsset(address pool) external {
        if (!IRegistry(REGISTRY).isAllowed(pool, 0)) revert PoolNotAllowed();

        // No need to check if token0 and token1 are allowed, since that was already checked when the pool was added.
        (address token0_, address token1_) = IAeroPool(pool).tokens();
        token0[pool] = token0_;
        token1[pool] = token1_;
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return allowed A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool allowed) {
        if (asset == address(this) && assetId <= lastPositionId) allowed = true;
    }

    /**
     * @notice Returns the unique identifiers of the underlying assets.
     * @param assetKey The unique identifier of the asset.
     * @return underlyingAssetKeys The unique identifiers of the underlying assets.
     */
    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        override
        returns (bytes32[] memory underlyingAssetKeys)
    {
        (, uint256 positionId) = _getAssetFromKey(assetKey);

        address pool = positionState[positionId].pool;
        underlyingAssetKeys = new bytes32[](3);
        underlyingAssetKeys[0] = _getKeyFromAsset(pool, 0);
        underlyingAssetKeys[1] = _getKeyFromAsset(token0[pool], 0);
        underlyingAssetKeys[2] = _getKeyFromAsset(token1[pool], 0);
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param amount The amount of the Asset, in the decimal precision of the Asset.
     * param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(address, bytes32 assetKey, uint256 amount, bytes32[] memory)
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        // Amount of a Wrapped position in the Asset Module can only be either 0 or 1.
        if (amount == 0) return (new uint256[](3), rateUnderlyingAssetsToUsd);

        (, uint256 positionId) = _getAssetFromKey(assetKey);
        (uint256 fee0Position, uint256 fee1Position) = feesOf(positionId);

        underlyingAssetsAmounts = new uint256[](3);
        underlyingAssetsAmounts[0] = positionState[positionId].amountWrapped;
        underlyingAssetsAmounts[1] = fee0Position;
        underlyingAssetsAmounts[2] = fee1Position;

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
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

        uint256[] memory underlyingAssetsAmounts;
        (underlyingAssetsAmounts,) = _getUnderlyingAssetsAmounts(creditor, assetKey, 1, underlyingAssetKeys);
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd =
            _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        (, uint256 collateralFactor_, uint256 liquidationFactor_) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);

        // Unsafe cast: collateralFactor_ and liquidationFactor_ are smaller than or equal to 1e4.
        return (uint16(collateralFactor_), uint16(liquidationFactor_));
    }

    /**
     * @notice Returns the USD value of an asset.
     * @param creditor The contract address of the Creditor.
     * @param underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @param rateUnderlyingAssetsToUsd The USD rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given Creditor, with 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given Creditor, with 4 decimals precision.
     * @dev We take a weighted risk factor of both underlying assets.
     */
    function _calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) internal view override returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        // "rateUnderlyingAssetsToUsd" is the USD value with 18 decimals precision for 10**18 tokens of Underlying Asset.
        // To get the USD value (also with 18 decimals) of the actual amount of underlying assets, we have to multiply
        // the actual amount with the rate for 10**18 tokens, and divide by 10**18.
        uint256 valuePool = underlyingAssetsAmounts[0].mulDivDown(rateUnderlyingAssetsToUsd[0].assetValue, 1e18);
        uint256 valueToken0 = underlyingAssetsAmounts[1].mulDivDown(rateUnderlyingAssetsToUsd[1].assetValue, 1e18);
        uint256 valueToken1 = underlyingAssetsAmounts[2].mulDivDown(rateUnderlyingAssetsToUsd[2].assetValue, 1e18);

        valueInUsd = valuePool + valueToken0 + valueToken1;

        // Calculate weighted risk factors.
        if (valueInUsd > 0) {
            unchecked {
                collateralFactor = (
                    valuePool * rateUnderlyingAssetsToUsd[0].collateralFactor
                        + valueToken0 * rateUnderlyingAssetsToUsd[1].collateralFactor
                        + valueToken1 * rateUnderlyingAssetsToUsd[2].collateralFactor
                ) / valueInUsd;
                liquidationFactor = (
                    valuePool * rateUnderlyingAssetsToUsd[0].liquidationFactor
                        + valueToken0 * rateUnderlyingAssetsToUsd[1].liquidationFactor
                        + valueToken1 * rateUnderlyingAssetsToUsd[2].liquidationFactor
                ) / valueInUsd;
            }
        }

        // Lower risk factors with the protocol wide risk factor.
        uint256 riskFactor = riskParams[creditor].riskFactor;
        collateralFactor = riskFactor.mulDivDown(collateralFactor, AssetValuationLib.ONE_4);
        liquidationFactor = riskFactor.mulDivDown(liquidationFactor, AssetValuationLib.ONE_4);
    }

    /*///////////////////////////////////////////////////////////////
                         WRAPPING MODULE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Wraps an amount of liquidity and mints a new position.
     * @param pool The contract address of the Aerodrome pool.
     * @param amount The amount of liquidity to wrap.
     * @return positionId The id of the minted position.
     */
    function mint(address pool, uint128 amount) external nonReentrant returns (uint256 positionId) {
        if (amount == 0) revert ZeroAmount();
        if (token0[pool] == address(0)) revert PoolNotAllowed();

        // Need to transfer before minting or ERC777s could reenter.
        ERC20(pool).safeTransferFrom(msg.sender, address(this), amount);

        // Cache the old poolState.
        PoolState memory poolState_ = poolState[pool];

        // Create a new positionState.
        PositionState memory positionState_;
        positionState_.pool = pool;

        // Claim any pending fees from the Aerodrome Pool.
        (uint256 fee0Pool, uint256 fee1Pool) = _claimFees(pool);

        // Calculate the new fee balances.
        (poolState_, positionState_) = _getFeeBalances(poolState_, positionState_, fee0Pool, fee1Pool);

        // Calculate the new wrapped amounts.
        poolState_.totalWrapped = poolState_.totalWrapped + amount;
        positionState_.amountWrapped = amount;

        // Store the new positionState and poolState.
        unchecked {
            positionId = ++lastPositionId;
        }
        positionState[positionId] = positionState_;
        poolState[pool] = poolState_;

        // Mint the new position.
        _safeMint(msg.sender, positionId);

        emit LiquidityIncreased(positionId, pool, amount);
    }

    /**
     * @notice Wraps additional liquidity for an existing position.
     * @param positionId The id of the position.
     * @param amount The amount of liquidity to wrap.
     */
    function increaseLiquidity(uint256 positionId, uint128 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Cache the old positionState and poolState.
        PositionState memory positionState_ = positionState[positionId];
        address pool = positionState_.pool;
        PoolState memory poolState_ = poolState[pool];

        // Need to transfer before increasing liquidity or ERC777s could reenter.
        ERC20(pool).safeTransferFrom(msg.sender, address(this), amount);

        // Claim any pending fees from the Aerodrome Pool.
        (uint256 fee0Pool, uint256 fee1Pool) = _claimFees(pool);

        // Calculate the new fee balances.
        (poolState_, positionState_) = _getFeeBalances(poolState_, positionState_, fee0Pool, fee1Pool);

        // Calculate the new wrapped amounts.
        poolState_.totalWrapped = poolState_.totalWrapped + amount;
        positionState_.amountWrapped = positionState_.amountWrapped + amount;

        // Store the new positionState and poolState.
        positionState[positionId] = positionState_;
        poolState[pool] = poolState_;

        emit LiquidityIncreased(positionId, pool, amount);
    }

    /**
     * @notice Unwraps, withdraws and claims fees for total amount of liquidity in position.
     * @param positionId The id of the position to burn.
     * @return fee0Position The amount of fees of token0 that can be claimed for a certain position.
     * @return fee1Position The amount of fees of token1 that can be claimed for a certain position.
     * @dev Also claims and transfers the fees of the position.
     */
    function burn(uint256 positionId) external returns (uint256 fee0Position, uint256 fee1Position) {
        return decreaseLiquidity(positionId, positionState[positionId].amountWrapped);
    }

    /**
     * @notice Unwraps and withdraws liquidity.
     * @param positionId The id of the position to withdraw from.
     * @param amount The amount of liquidity to unwrap and withdraw.
     * @return fee0Position The amount of fees of token0 that can be claimed for a certain position.
     * @return fee1Position The amount of fees of token1 that can be claimed for a certain position.
     * @dev Also claims and transfers the fees of the position.
     */
    function decreaseLiquidity(uint256 positionId, uint128 amount)
        public
        nonReentrant
        returns (uint256 fee0Position, uint256 fee1Position)
    {
        if (amount == 0) revert ZeroAmount();
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Cache the old positionState and poolState.
        PositionState memory positionState_ = positionState[positionId];
        address pool = positionState_.pool;
        PoolState memory poolState_ = poolState[pool];

        // Claim any pending fees from the Aerodrome Pool.
        (uint256 fee0Pool, uint256 fee1Pool) = _claimFees(pool);

        // Calculate the new fee balances.
        (poolState_, positionState_) = _getFeeBalances(poolState_, positionState_, fee0Pool, fee1Pool);

        // Calculate the new wrapped amounts, reverts if balance is too low.
        poolState_.totalWrapped = poolState_.totalWrapped - amount;
        positionState_.amountWrapped = positionState_.amountWrapped - amount;

        // Fees are paid out to the owner on a decreaseLiquidity.
        // -> Reset the balances of the pending fees.
        fee0Position = positionState_.fee0;
        fee1Position = positionState_.fee1;
        positionState_.fee0 = 0;
        positionState_.fee1 = 0;

        // Store the new positionState and poolState.
        if (positionState_.amountWrapped > 0) {
            positionState[positionId] = positionState_;
        } else {
            delete positionState[positionId];
            _burn(positionId);
        }
        poolState[pool] = poolState_;

        // Pay out the fees to the position owner.
        ERC20(token0[pool]).safeTransfer(msg.sender, fee0Position);
        ERC20(token1[pool]).safeTransfer(msg.sender, fee1Position);
        emit FeesPaid(positionId, uint128(fee0Position), uint128(fee1Position));

        // Transfer the liquidity back to the position owner.
        ERC20(pool).safeTransfer(msg.sender, amount);
        emit LiquidityDecreased(positionId, pool, amount);
    }

    /**
     * @notice Claims and transfers the fees of the position.
     * @param positionId The id of the position.
     * @return fee0Position The amount of fees of token0 that can be claimed for a certain position.
     * @return fee1Position The amount of fees of token1 that can be claimed for a certain position.
     */
    function claimFees(uint256 positionId) external nonReentrant returns (uint256 fee0Position, uint256 fee1Position) {
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Cache the old positionState and poolState.
        PositionState memory positionState_ = positionState[positionId];
        address pool = positionState_.pool;
        PoolState memory poolState_ = poolState[pool];

        // Claim any pending fees from the Aerodrome Pool.
        (uint256 fee0Pool, uint256 fee1Pool) = _claimFees(pool);

        // Calculate the new fee balances.
        (poolState_, positionState_) = _getFeeBalances(poolState_, positionState_, fee0Pool, fee1Pool);

        // Fees are paid out to the owner on a claimFees.
        // -> Reset the balances of the pending fees.
        fee0Position = positionState_.fee0;
        fee1Position = positionState_.fee1;
        positionState_.fee0 = 0;
        positionState_.fee1 = 0;

        // Store the new positionState and poolState.
        positionState[positionId] = positionState_;
        poolState[pool] = poolState_;

        // Pay out the fees to the position owner.
        ERC20(token0[pool]).safeTransfer(msg.sender, fee0Position);
        ERC20(token1[pool]).safeTransfer(msg.sender, fee1Position);
        emit FeesPaid(positionId, uint128(fee0Position), uint128(fee1Position));
    }

    /**
     * @notice Skims any surplus pool-tokens to the owner.
     * @param pool The contract address of the Aerodrome pool.
     * @dev If pool tokens are transferred without depositing before any position is minted,
     * the pool can have non zero fees balances while totalWrapped_ is 0.
     * In this case the fees are not accounted for and will be lost.
     */
    function skim(address pool) external onlyOwner nonReentrant {
        if (token0[pool] == address(0)) revert PoolNotAllowed();

        // Claim any pending fees from the Aerodrome Pool.
        (uint256 fee0Pool, uint256 fee1Pool) = _claimFees(pool);

        // Cache the poolState.
        PoolState memory poolState_ = poolState[pool];

        // Calculate the new fee balances.
        PositionState memory positionState_;
        (poolState_,) = _getFeeBalances(poolState_, positionState_, fee0Pool, fee1Pool);

        // Store the new poolState.
        poolState[pool] = poolState_;

        // Transfer excess funds to the owner.
        uint256 deltaWrapped = ERC20(pool).balanceOf(address(this)) - poolState_.totalWrapped;
        ERC20(pool).safeTransfer(msg.sender, deltaWrapped);
    }

    /**
     * @notice Returns the total amount of liquidity wrapped via this contract.
     * @param pool The contract address of the Aerodrome pool.
     * @return totalWrapped_ The total amount of liquidity wrapped via this contract.
     */
    function totalWrapped(address pool) external view returns (uint256 totalWrapped_) {
        totalWrapped_ = poolState[pool].totalWrapped;
    }

    /*///////////////////////////////////////////////////////////////
                     INTERACTIONS AERODROME POOL
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Claims the fees available for this contract.
     * @param pool The contract address of the Aerodrome pool to claim the fees for.
     * @return fee0 The amount of fees of token0 claimed.
     * @return fee1 The amount of fees of token1 claimed.
     */
    function _claimFees(address pool) internal returns (uint256 fee0, uint256 fee1) {
        (fee0, fee1) = IAeroPool(pool).claimFees();
    }

    /**
     * @notice Returns the amount of fees that can be claimed by this contract for a specific asset.
     * @param pool The contract address of the Aerodrome pool to get the current fees for.
     * @return fee0 The amount of fees of token0 that can be claimed by this contract.
     * @return fee1 The amount of fees of token1 that can be claimed by this contract.
     * @dev If pool tokens are transferred without depositing before any position is minted,
     * the pool can have non zero fees balances while totalWrapped_ is 0.
     * In this case the fees are not accounted for and will be lost.
     */
    function _getCurrentFees(address pool) internal view returns (uint256 fee0, uint256 fee1) {
        // Cache totalWrapped.
        uint256 totalWrapped_ = poolState[pool].totalWrapped;

        if (totalWrapped_ > 0) {
            // Unfortunately Aerodrome does not have a view function to get pending fees.
            fee0 = IAeroPool(pool).claimable0(address(this))
                + totalWrapped_.mulDivDown(IAeroPool(pool).index0() - IAeroPool(pool).supplyIndex0(address(this)), 1e18);
            fee1 = IAeroPool(pool).claimable1(address(this))
                + totalWrapped_.mulDivDown(IAeroPool(pool).index1() - IAeroPool(pool).supplyIndex1(address(this)), 1e18);
        }
    }

    /*///////////////////////////////////////////////////////////////
                         REWARDS VIEW FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the amount of fees claimable by a position.
     * @param positionId The id of the position to check the fees for.
     * @return fee0Position The amount of fees of token0 that can be claimed for a certain position.
     * @return fee1Position The amount of fees of token1 that can be claimed for a certain position.
     */
    function feesOf(uint256 positionId) public view returns (uint256 fee0Position, uint256 fee1Position) {
        // Cache the old positionState and poolState.
        PositionState memory positionState_ = positionState[positionId];
        PoolState memory poolState_ = poolState[positionState_.pool];

        // Calculate the new fee balances.
        (uint256 fee0Pool, uint256 fee1Pool) = _getCurrentFees(positionState_.pool);
        (, positionState_) = _getFeeBalances(poolState_, positionState_, fee0Pool, fee1Pool);

        fee0Position = positionState_.fee0;
        fee1Position = positionState_.fee1;
    }

    /**
     * @notice Calculates the current global and position specific fee balances.
     * @param poolState_ Struct with the old fees state of the Asset.
     * @param positionState_ Struct with the old fees state of the position.
     * @return currentPoolState Struct with the current fees state of the Asset.
     * @return currentPositionState Struct with the current fees state of the position.
     */
    function _getFeeBalances(
        PoolState memory poolState_,
        PositionState memory positionState_,
        uint256 fee0,
        uint256 fee1
    ) internal pure returns (PoolState memory, PositionState memory) {
        if (poolState_.totalWrapped > 0) {
            // Calculate the new poolState.
            // Calculate the change in FeePerLiquidity.
            uint256 deltaFee0PerLiquidity = fee0.mulDivDown(1e18, poolState_.totalWrapped);
            uint256 deltaFee1PerLiquidity = fee1.mulDivDown(1e18, poolState_.totalWrapped);
            // Calculate and update the new FeePerLiquidity of the Pool.
            // unchecked: FeePerLiquidity can overflow, what matters is the delta in FeePerLiquidity between two interactions.
            unchecked {
                poolState_.fee0PerLiquidity = poolState_.fee0PerLiquidity + deltaFee0PerLiquidity.safeCastTo128();
                poolState_.fee1PerLiquidity = poolState_.fee1PerLiquidity + deltaFee1PerLiquidity.safeCastTo128();
            }

            if (positionState_.amountWrapped > 0) {
                // Calculate the new positionState.
                // Calculate the difference in feePerLiquidity since the last position interaction.
                // unchecked: FeePerLiquidity can underflow, what matters is the delta in FeePerLiquidity between two interactions.
                unchecked {
                    deltaFee0PerLiquidity = poolState_.fee0PerLiquidity - positionState_.fee0PerLiquidity;
                    deltaFee1PerLiquidity = poolState_.fee1PerLiquidity - positionState_.fee1PerLiquidity;
                }
                // Calculate the fees earned by the position since its last interaction.
                // unchecked: deltaFeePerLiquidity and positionState_.amountWrapped are smaller than type(uint128).max.
                uint256 deltaFee0;
                uint256 deltaFee1;
                unchecked {
                    deltaFee0 = deltaFee0PerLiquidity * positionState_.amountWrapped / 1e18;
                    deltaFee1 = deltaFee1PerLiquidity * positionState_.amountWrapped / 1e18;
                }
                // Update the fee balance of the position.
                positionState_.fee0 = (positionState_.fee0 + deltaFee0).safeCastTo128();
                positionState_.fee1 = (positionState_.fee1 + deltaFee1).safeCastTo128();
            }
        }
        // Update the FeePerLiquidity of the position.
        positionState_.fee0PerLiquidity = poolState_.fee0PerLiquidity;
        positionState_.fee1PerLiquidity = poolState_.fee1PerLiquidity;

        return (poolState_, positionState_);
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
}
