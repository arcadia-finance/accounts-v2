/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { IOraclesHub } from "./interfaces/IOraclesHub.sol";
import { IPricingModule, PrimaryPricingModule } from "./AbstractPrimaryPricingModule.sol";
import { IStandardERC20PricingModule } from "./interfaces/IStandardERC20PricingModule.sol";

/**
 * @title Pricing Module for Standard ERC20 tokens.
 * @author Pragma Labs
 * @notice The pricing logic and basic information for ERC20 tokens for which a direct price feed exists.
 * @dev No end-user should directly interact with the StandardERC20PricingModule, only the Main-registry,
 * Oracle-Hub or the contract owner.
 */
contract StandardERC20PricingModule is PrimaryPricingModule, IStandardERC20PricingModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map asset => assetInformation.
    mapping(address => AssetInformation) public assetToInformation;

    // Struct with additional information for a specific asset.
    struct AssetInformation {
        uint64 assetUnit; // The unit of the asset, equal to 10^decimals.
        address[] oracles; // Array of contract addresses of oracles.
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The contract address of the MainRegistry.
     * @param oracleHub_ The contract address of the OracleHub.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC20 tokens is 0.
     */
    constructor(address mainRegistry_, address oracleHub_) PrimaryPricingModule(mainRegistry_, oracleHub_, 0) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the StandardERC20PricingModule.
     * @param asset The contract address of the asset.
     * @param oracles An array of contract addresses of oracles, to price the asset in USD.
     * @param riskVars An array of RiskVarInput structs.
     * @dev Assets can't have more than 18 decimals.
     * @dev The asset slot in the RiskVarInput struct can be any value as it is not used in this function.
     * @dev If no risk variables are provided, the asset is added with the risk variables set by default to zero,
     * resulting in the asset being valued at 0.
     * @dev Risk variables are variables with 2 decimals precision.
     */
    function addAsset(address asset, address[] calldata oracles, RiskVarInput[] calldata riskVars) external onlyOwner {
        // View function, reverts in OracleHub if sequence is not correct.
        IOraclesHub(ORACLE_HUB).checkOracleSequence(oracles, asset);

        inPricingModule[asset] = true;

        uint256 assetUnit = 10 ** IERC20(asset).decimals();
        require(assetUnit <= 1e18, "PM20_AA: Maximal 18 decimals");

        // Can safely cast to uint64, we previously checked it is smaller than 10e18.
        assetToInformation[asset].assetUnit = uint64(assetUnit);
        assetToInformation[asset].oracles = oracles;
        _setRiskVariablesForAsset(asset, riskVars);

        // Will revert in MainRegistry if asset was already added.
        IMainRegistry(MAIN_REGISTRY).addAsset(asset, ASSET_TYPE);
    }

    /**
     * @notice Sets a new oracle sequence in the case one of the current oracles is decommissioned.
     * @param asset The contract address of the asset.
     * @param newOracles An array of contract addresses of oracles, to price the asset in USD.
     * @param decommissionedOracle The contract address of the decommissioned oracle.
     */
    function setOracles(address asset, address[] calldata newOracles, address decommissionedOracle)
        external
        onlyOwner
    {
        // If asset is not added to the Pricing Module, oldOracles will have length 0,
        // in this case the for loop will be skipped and the function will revert.
        address[] memory oldOracles = assetToInformation[asset].oracles;
        uint256 oraclesLength = oldOracles.length;
        for (uint256 i; i < oraclesLength;) {
            if (oldOracles[i] == decommissionedOracle) {
                require(!IOraclesHub(ORACLE_HUB).isActive(oldOracles[i]), "PM20_SO: Oracle still active");
                // View function, reverts in OracleHub if sequence is not correct.
                IOraclesHub(ORACLE_HUB).checkOracleSequence(newOracles, asset);
                assetToInformation[asset].oracles = newOracles;
                return;
            }
            unchecked {
                ++i;
            }
        }
        // We only arrive in tis state if length of oldOracles was zero, or decommissionedOracle was not in the oldOracles array.
        // -> reverts.
        revert("PM20_SO: Unknown Oracle");
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the asset information of an asset.
     * @param asset The contract address of the asset.
     * @return assetUnit The unit (10^decimals) of the asset.
     * @return oracles An array of contract addresses of oracles, to price the asset in USD.
     */
    function getAssetInformation(address asset) external view returns (uint64, address[] memory) {
        return (assetToInformation[asset].assetUnit, assetToInformation[asset].oracles);
    }

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     * @dev Since ERC20s don't have an Id, the Id should be set to 0.
     */
    function isAllowed(address asset, uint256) public view override returns (bool) {
        return inPricingModule[asset];
    }

    /**
     * @notice Returns the unique identifier of an asset based on the contract address and id.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return key The unique identifier.
     * @dev The assetId is hard-coded to 0, since the assets for this Pricing Modules are ERC20's.
     */
    function _getKeyFromAsset(address asset, uint256) internal pure override returns (bytes32 key) {
        assembly {
            key := asset
        }
    }

    /**
     * @notice Returns the contract address and id of an asset based on the unique identifier.
     * @param key The unique identifier.
     * @return asset The contract address of the asset.
     * @return assetId The Id of the asset.
     * @dev The assetId is hard-coded to 0, since the assets for this Pricing Modules are ERC20's.
     */
    function _getAssetFromKey(bytes32 key) internal pure override returns (address asset, uint256) {
        assembly {
            asset := key
        }

        return (asset, 0);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the usd value of an asset.
     * @param getValueInput A Struct with the input variables.
     * - asset: The contract address of the asset.
     * - assetId: Since ERC20 tokens have no Id, the Id should be set to 0.
     * - assetAmount: The amount of assets.
     * - baseCurrency: The BaseCurrency in which the value is ideally denominated.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256.
     * @dev If the asset is not added to PricingModule, this function will return value 0 without throwing an error.
     * However no check in StandardERC20PricingModule is necessary, since the check if the asset is added to the PricingModule
     * is already done in the MainRegistry.
     */
    function getValue(IPricingModule.GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        uint256 rateInUsd = IOraclesHub(ORACLE_HUB).getRateInUsd(assetToInformation[getValueInput.asset].oracles);

        valueInUsd = getValueInput.assetAmount.mulDivDown(rateInUsd, assetToInformation[getValueInput.asset].assetUnit);

        collateralFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liquidationFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationFactor;
    }
}
