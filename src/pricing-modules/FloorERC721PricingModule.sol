/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { PrimaryPricingModule, IPricingModule } from "./AbstractPrimaryPricingModule.sol";
import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { IOraclesHub } from "./interfaces/IOraclesHub.sol";

/**
 * @title Pricing Module for ERC721 tokens for which a oracle exists for the floor price of the collection
 * @author Pragma Labs
 * @notice The FloorERC721PricingModule stores pricing logic and basic information for ERC721 tokens for which a direct price feeds exists
 * for the floor price of the collection
 * @dev No end-user should directly interact with the FloorERC721PricingModule, only the Main-registry, Oracle-Hub or the contract owner
 */
contract FloorERC721PricingModule is PrimaryPricingModule {
    mapping(address => AssetInformation) public assetToInformation;

    struct AssetInformation {
        uint256 idRangeStart;
        uint256 idRangeEnd;
        address[] oracles;
    }

    /**
     * @notice A Pricing Module must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry_ The address of the Main-registry
     * @param oracleHub_ The address of the Oracle-Hub
     * @param assetType_ Identifier for the type of asset, necessary for the deposit and withdraw logic in the Accounts.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     */
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_)
        PrimaryPricingModule(mainRegistry_, oracleHub_, assetType_, msg.sender)
    { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the FloorERC721PricingModule.
     * @param asset The contract address of the asset
     * @param idRangeStart: The id of the first NFT of the collection
     * @param idRangeEnd: The id of the last NFT of the collection
     * @param oracles An array of addresses of oracle contracts, to price the asset in USD
     * @param riskVars An array of Risk Variables for the asset
     * @param maxExposure The maximum exposure of the asset in its own decimals
     * @dev Only the Collateral Factor, Liquidation Threshold and basecurrency are taken into account.
     * If no risk variables are provided, the asset is added with the risk variables set to zero, meaning it can't be used as collateral.
     * @dev RiskVarInput.asset can be zero as it is not taken into account.
     * @dev Risk variable are variables with 2 decimals precision
     * @dev The assets are added in the Main-Registry as well.
     */
    function addAsset(
        address asset,
        uint256 idRangeStart,
        uint256 idRangeEnd,
        address[] calldata oracles,
        RiskVarInput[] calldata riskVars,
        uint256 maxExposure
    ) external onlyOwner {
        //View function, reverts in OracleHub if sequence is not correct
        IOraclesHub(oracleHub).checkOracleSequence(oracles, asset);

        require(!inPricingModule[asset], "PM721_AA: already added");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        assetToInformation[asset].idRangeStart = idRangeStart;
        assetToInformation[asset].idRangeEnd = idRangeEnd;
        assetToInformation[asset].oracles = oracles;
        _setRiskVariablesForAsset(asset, riskVars);

        require(maxExposure <= type(uint128).max, "PM721_AA: Max Exposure not in limits");
        exposure[asset].maxExposure = uint128(maxExposure);

        //Will revert in MainRegistry if asset can't be added
        IMainRegistry(mainRegistry).addAsset(asset, assetType);
    }

    /**
     * @notice Returns the information that is stored in the Pricing Module for a given asset
     * @dev struct is not taken into memory; saves 6613 gas
     * @param asset The Token address of the asset
     * @return idRangeStart The id of the first token of the collection
     * @return idRangeEnd The id of the last token of the collection
     * @return oracles The list of addresses of the oracles to get the exchange rate of the asset in USD
     */
    function getAssetInformation(address asset) external view returns (uint256, uint256, address[] memory) {
        return (
            assetToInformation[asset].idRangeStart,
            assetToInformation[asset].idRangeEnd,
            assetToInformation[asset].oracles
        );
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the asset passed as input is whitelisted
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool) {
        if (exposure[asset].maxExposure != 0) {
            if (isIdInRange(asset, assetId)) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Checks if the Id for a given token is in the range for which there exists a price feed
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the Id of the given asset is whitelisted
     */
    function isIdInRange(address asset, uint256 assetId) private view returns (bool) {
        if (assetId >= assetToInformation[asset].idRangeStart && assetId <= assetToInformation[asset].idRangeEnd) {
            return true;
        } else {
            return false;
        }
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Processes the deposit of a token address and the corresponding Id if it is white-listed
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @param amount the amount of ERC721 tokens
     * @dev amount of a deposit in ERC721 pricing module must be 1
     */
    function processDirectDeposit(address asset, uint256 assetId, uint256 amount) public override onlyMainReg {
        require(isIdInRange(asset, assetId), "PM721_PDD: ID not allowed");
        require(amount == 1, "PM721_PDD: Amount not 1");
        require(exposure[asset].exposure + 1 <= exposure[asset].maxExposure, "PM721_PDD: Exposure not in limits");

        exposure[asset].exposure += 1;
    }

    /**
     * @notice Increases the exposure to an underlying asset on deposit.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function processIndirectDeposit(
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        require(isIdInRange(asset, assetId), "PM721_PID: ID not allowed");
        // Cache exposureLast.
        uint256 exposureLast = exposure[asset].exposure;

        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            exposureAsset = exposureLast + uint256(deltaExposureUpperAssetToAsset);
            require(exposureAsset <= exposure[asset].maxExposure, "PM721_PID: Exposure not in limits");
        } else {
            exposureAsset = exposureLast > uint256(-deltaExposureUpperAssetToAsset)
                ? exposureLast - uint256(-deltaExposureUpperAssetToAsset)
                : 0;
        }
        exposure[asset].exposure = uint128(exposureAsset);

        // Get Value in Usd
        (uint256 floorUsdValue,,) =
            getValue(IPricingModule.GetValueInput({ asset: asset, assetId: 0, assetAmount: 1, baseCurrency: 0 }));

        usdValueExposureUpperAssetToAsset = floorUsdValue * exposureUpperAssetToAsset;

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }

    /**
     * @notice Processes the withdrawal of tokens to increase the maxExposure
     * @param asset The address of the asset
     * @param amount the amount of ERC721 tokens
     * @dev amount of a deposit in ERC721 pricing module must be 1
     */
    function processDirectWithdrawal(address asset, uint256, uint256 amount) external override onlyMainReg {
        require(amount == 1, "PM721_PDW: Amount not 1");
        exposure[asset].exposure -= 1;
    }

    /**
     * @notice Decreases the exposure to an underlying asset on withdrawal.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function processIndirectWithdrawal(
        address asset,
        uint256,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) external virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        // Cache exposureLast.
        uint256 exposureLast = exposure[asset].exposure;

        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            exposureAsset = exposureLast + uint256(deltaExposureUpperAssetToAsset);
            require(exposureAsset <= type(uint128).max, "APPM_PIW: Overflow");
        } else {
            exposureAsset = exposureLast > uint256(-deltaExposureUpperAssetToAsset)
                ? exposureLast - uint256(-deltaExposureUpperAssetToAsset)
                : 0;
        }
        exposure[asset].exposure = uint128(exposureAsset);

        // Get Value in Usd
        (uint256 floorUsdValue,,) =
            getValue(IPricingModule.GetValueInput({ asset: asset, assetId: 0, assetAmount: 1, baseCurrency: 0 }));

        usdValueExposureUpperAssetToAsset = floorUsdValue * exposureUpperAssetToAsset;

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the usd value of an asset.
     * @param getValueInput A Struct with the input variables.
     * - asset: The contract address of the asset.
     * - assetId: The Id of the asset
     * - assetAmount: Since ERC721 tokens have no amount, the amount should be set to 1.
     * - baseCurrency: The BaseCurrency in which the value is ideally denominated.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @dev If the asset is not first added to PricingModule this function will return value 0 without throwing an error.
     * However no check in FloorERC721PricingModule is necessary, since the check if the asset is added to the PricingModule
     * is already done in the MainRegistry.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        valueInUsd = IOraclesHub(oracleHub).getRateInUsd(assetToInformation[getValueInput.asset].oracles);

        collateralFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liquidationFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationFactor;
    }
}
