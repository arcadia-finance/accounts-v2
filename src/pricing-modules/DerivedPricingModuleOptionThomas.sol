/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { IPricingModule } from "../interfaces/IPricingModuleOptionThomas.sol";
import { Owned } from "../../lib/solmate/src/auth/Owned.sol";

/**
 * @title Derived Pricing Module.
 * @author Pragma Labs
 */
abstract contract DerivedPricingModule is Owned, IPricingModule {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    bool internal constant PRIMARY_FLAG = false;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The maximum total exposure of the protocol of this Pricing Module, denominated in USD with 18 decimals precision.
    uint256 maxUsdExposure;
    // The actual exposure of the protocol of this Pricing Module, denominated in USD with 18 decimals precision.
    uint256 usdExposure;

    // The contract address of the MainRegistry.
    address public immutable mainRegistry;
    // The contract address of the OracleHub.
    address public immutable oracleHub;
    // Identifier for the token standard of the asset.
    uint256 public immutable assetType;
    // The address of the riskManager.
    address public riskManager;

    // Array with all the contract addresses of assets added to the Pricing Module.
    address[] public assetsInPricingModule;

    // Map asset => flag.
    mapping(address => bool) public inPricingModule;
    // Map asset => assetExposure.
    mapping(address => uint256) public assetExposure;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event RiskManagerUpdated(address riskManager);
    event MaxUsdExposureSet(uint256 maxExposure);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    modifier onlyRiskManager() {
        require(msg.sender == riskManager, "APM: ONLY_RISK_MANAGER");
        _;
    }

    modifier onlyMainReg() {
        require(msg.sender == mainRegistry, "APM: ONLY_MAIN_REGISTRY");
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The contract address of the MainRegistry.
     * @param oracleHub_ The contract address of the OracleHub.
     * @param assetType_ Identifier for the token standard of the asset.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     * @param riskManager_ The address of the Risk Manager.
     */
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        Owned(msg.sender)
    {
        mainRegistry = mainRegistry_;
        oracleHub = oracleHub_;
        assetType = assetType_;
        riskManager = riskManager_;

        emit RiskManagerUpdated(riskManager_);
    }

    /*///////////////////////////////////////////////////////////////
                    RISK MANAGER MANAGEMENT
    ///////////////////////////////////////////////////////////////*/
    /**
     * @notice Sets a new Risk Manager.
     * @param riskManager_ The address of the new Risk Manager.
     */
    function setRiskManager(address riskManager_) external onlyOwner {
        riskManager = riskManager_;

        emit RiskManagerUpdated(riskManager_);
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is whitelisted.
     * @dev For assets without Id (ERC20, ERC4626...), the Id should be set to 0.
     */
    function isAllowListed(address asset, uint256) public view virtual returns (bool) { }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the value of a certain asset, denominated in USD, 18 decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, 2 decimals precision.
     */
    function getValue(GetValueInput memory) public view virtual returns (uint256, uint256, uint256) { }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk variables of an asset.
     * @param asset The contract address of the asset.
     * @param baseCurrency An identifier (uint256) of the BaseCurrency.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, 2 decimals precision.
     */
    function getRiskVariables(address asset, uint256 baseCurrency) public view virtual returns (uint16, uint16) { }

    /**
     * @notice Sets the maximum exposure for the protocol.
     * @param maxUsdExposure_ The maximum total exposure of the protocol of this Pricing Module, denominated in USD with 18 decimals precision.
     * @dev Can only be called by the Risk Manager, which can be different from the owner.
     */
    function setMaxUsdExposure(uint256 maxUsdExposure_) public virtual onlyRiskManager {
        maxUsdExposure = maxUsdExposure_;

        emit MaxUsdExposureSet(maxUsdExposure_);
    }

    function processDirectDeposit(address asset, uint256, uint256 amount) external virtual onlyMainReg { }

    function processIndirectDeposit(address asset, uint256, int256 amount)
        external
        virtual
        onlyMainReg
        returns (bool primaryFlag, uint256 valueInUsd)
    { }

    /**
     * @notice Decreases the exposure to an asset on withdrawal.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @param amount The amount of tokens.
     * @dev Unsafe cast to uint128, it is assumed no more than 10**(20+decimals) tokens will ever be deposited.
     */
    function processDirectWithdrawal(address asset, uint256, uint256 amount) external virtual onlyMainReg { }

    function processIndirectWithdrawal(address asset, uint256, int256 amount)
        external
        virtual
        onlyMainReg
        returns (bool primaryFlag, uint256 valueInUsd)
    { }
}
