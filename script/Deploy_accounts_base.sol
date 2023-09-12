/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses, DeployNumbers, DeployBytes, DeployRiskConstantsBase } from "./Constants/DeployConstants.sol";

import { Factory } from "../src/Factory.sol";
import { AccountV1 } from "../src/AccountV1.sol";
import { MainRegistry_UsdOnly } from "../src/MainRegistry_UsdOnly.sol";
import {
    PricingModule_UsdOnly,
    StandardERC20PricingModule_UsdOnly
} from "../src/pricing-modules/StandardERC20PricingModule_UsdOnly.sol";
import { UniswapV3PricingModule_UsdOnly } from "../src/pricing-modules/UniswapV3/UniswapV3PricingModule_UsdOnly.sol";
import { OracleHub } from "../src/OracleHub.sol";

import { ActionMultiCallV2 } from "../src/actions/MultiCallV2.sol";

import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { ERC20 } from "../lib/solmate/src/tokens/ERC20.sol";

contract ArcadiaAccountDeployment is Test {
    Factory public factory;
    AccountV1 public account;

    ERC20 public comp;
    ERC20 public dai;
    ERC20 public weth;
    ERC20 public usdc;
    ERC20 public cbeth;
    ERC20 public reth;

    OracleHub public oracleHub;
    MainRegistry_UsdOnly public mainRegistry;
    StandardERC20PricingModule_UsdOnly public standardERC20PricingModule;
    UniswapV3PricingModule_UsdOnly public uniswapV3PricingModule;
    ActionMultiCallV2 public actionMultiCall;

    ILendingPool public wethLendingPool;
    ILendingPool public usdcLendingPool;

    address[] public oracleCompToUsdArr = new address[](1);
    address[] public oracleDaiToUsdArr = new address[](1);
    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleUsdcToUsdArr = new address[](1);
    address[] public oracleCbethToEthToUsdArr = new address[](2);
    address[] public oracleRethToEthToUsdArr = new address[](2);

    PricingModule_UsdOnly.RiskVarInput[] public riskVarsComp;
    PricingModule_UsdOnly.RiskVarInput[] public riskVarsDai;
    PricingModule_UsdOnly.RiskVarInput[] public riskVarsEth;
    PricingModule_UsdOnly.RiskVarInput[] public riskVarsUsdc;
    PricingModule_UsdOnly.RiskVarInput[] public riskVarsCbeth;
    PricingModule_UsdOnly.RiskVarInput[] public riskVarsReth;

    OracleHub.OracleInformation public compToUsdOracleInfo;
    OracleHub.OracleInformation public daiToUsdOracleInfo;
    OracleHub.OracleInformation public ethToUsdOracleInfo;
    OracleHub.OracleInformation public usdcToUsdOracleInfo;
    OracleHub.OracleInformation public cbethToEthToUsdOracleInfo;
    OracleHub.OracleInformation public rethToEthOracleInfo;

    MainRegistry_UsdOnly.BaseCurrencyInformation public usdBaseCurrencyInfo;
    MainRegistry_UsdOnly.BaseCurrencyInformation public ethBaseCurrencyInfo;
    MainRegistry_UsdOnly.BaseCurrencyInformation public usdcBaseCurrencyInfo;

    constructor() {
        // /*///////////////////////////////////////////////////////////////
        //                   ADDRESSES
        // ///////////////////////////////////////////////////////////////*/

        comp = ERC20(DeployAddresses.comp_base);
        dai = ERC20(DeployAddresses.dai_base);
        weth = ERC20(DeployAddresses.weth_base);
        usdc = ERC20(DeployAddresses.usdc_base);
        cbeth = ERC20(DeployAddresses.cbeth_base);
        reth = ERC20(DeployAddresses.reth_base);

        // /*///////////////////////////////////////////////////////////////
        //                   ORACLE TRAINS
        // ///////////////////////////////////////////////////////////////*/

        oracleCompToUsdArr[0] = DeployAddresses.oracleCompToUsd_base;
        oracleDaiToUsdArr[0] = DeployAddresses.oracleDaiToUsd_base;
        oracleEthToUsdArr[0] = DeployAddresses.oracleEthToUsd_base;
        oracleUsdcToUsdArr[0] = DeployAddresses.oracleUsdcToUsd_base;
        oracleCbethToEthToUsdArr[0] = DeployAddresses.oracleCbethToEth_base;
        oracleCbethToEthToUsdArr[1] = DeployAddresses.oracleEthToUsd_base;
        oracleRethToEthToUsdArr[0] = DeployAddresses.oracleRethToEth_base;
        oracleRethToEthToUsdArr[1] = DeployAddresses.oracleEthToUsd_base;

        // /*///////////////////////////////////////////////////////////////
        //                   ORACLE INFO
        // ///////////////////////////////////////////////////////////////*/

        compToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleCompToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "COMP",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleCompToUsd_base,
            baseAssetAddress: DeployAddresses.comp_base,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        daiToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleDaiToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "DAI",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleDaiToUsd_base,
            baseAssetAddress: DeployAddresses.dai_base,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        ethToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "ETH",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleEthToUsd_base,
            baseAssetAddress: DeployAddresses.weth_base,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        usdcToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.UsdBaseCurrency),
            baseAsset: "USDC",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleUsdcToUsd_base,
            baseAssetAddress: DeployAddresses.usdc_base,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        cbethToEthToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleCbethToEthUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.EthBaseCurrency),
            baseAsset: "CBETH",
            quoteAsset: "ETH",
            oracle: DeployAddresses.oracleCbethToEth_base,
            baseAssetAddress: DeployAddresses.cbeth_base,
            quoteAssetIsBaseCurrency: true,
            isActive: true
        });

        rethToEthOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleRethToEthUnit),
            quoteAssetBaseCurrency: uint8(DeployNumbers.EthBaseCurrency),
            baseAsset: "RETH",
            quoteAsset: "ETH",
            oracle: DeployAddresses.oracleRethToEth_base,
            baseAssetAddress: DeployAddresses.reth_base,
            quoteAssetIsBaseCurrency: false,
            isActive: true
        });

        ethBaseCurrencyInfo = MainRegistry_UsdOnly.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            assetAddress: DeployAddresses.weth_base,
            baseCurrencyToUsdOracle: DeployAddresses.oracleEthToUsd_base,
            baseCurrencyLabel: "wETH",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.wethDecimals))
        });

        usdcBaseCurrencyInfo = MainRegistry_UsdOnly.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            assetAddress: DeployAddresses.usdc_base,
            baseCurrencyToUsdOracle: DeployAddresses.oracleUsdcToUsd_base,
            baseCurrencyLabel: "USDC",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.usdcDecimals))
        });

        /*///////////////////////////////////////////////////////////////
                            RISK VARS
        ///////////////////////////////////////////////////////////////*/

        riskVarsComp.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.comp_collFact_1,
                liquidationFactor: DeployRiskConstantsBase.comp_liqFact_1
            })
        );
        riskVarsComp.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.comp_collFact_2,
                liquidationFactor: DeployRiskConstantsBase.comp_liqFact_2
            })
        );

        riskVarsDai.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.dai_collFact_1,
                liquidationFactor: DeployRiskConstantsBase.dai_liqFact_1
            })
        );
        riskVarsDai.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.dai_collFact_2,
                liquidationFactor: DeployRiskConstantsBase.dai_liqFact_2
            })
        );

        riskVarsEth.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.eth_collFact_1,
                liquidationFactor: DeployRiskConstantsBase.eth_liqFact_1
            })
        );
        riskVarsEth.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.eth_collFact_2,
                liquidationFactor: DeployRiskConstantsBase.eth_liqFact_2
            })
        );

        riskVarsUsdc.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.usdc_collFact_1,
                liquidationFactor: DeployRiskConstantsBase.usdc_liqFact_1
            })
        );
        riskVarsUsdc.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.usdc_collFact_2,
                liquidationFactor: DeployRiskConstantsBase.usdc_liqFact_2
            })
        );

        riskVarsCbeth.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.cbeth_collFact_1,
                liquidationFactor: DeployRiskConstantsBase.cbeth_liqFact_1
            })
        );
        riskVarsCbeth.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.cbeth_collFact_2,
                liquidationFactor: DeployRiskConstantsBase.cbeth_liqFact_2
            })
        );

        riskVarsReth.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 0,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.reth_collFact_1,
                liquidationFactor: DeployRiskConstantsBase.reth_liqFact_1
            })
        );
        riskVarsReth.push(
            PricingModule_UsdOnly.RiskVarInput({
                baseCurrency: 1,
                asset: address(0),
                collateralFactor: DeployRiskConstantsBase.reth_collFact_2,
                liquidationFactor: DeployRiskConstantsBase.reth_liqFact_2
            })
        );
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        factory = Factory(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707); //todo: change after factory deploy
        wethLendingPool = ILendingPool(0xa513E6E4b8f2a923D98304ec87F64353C4D5C853); //todo: change after LP deploy
        usdcLendingPool = ILendingPool(0x3Aa5ebB10DC797CAC828524e59A333d0A371443c); //todo: change after LP deploy

        mainRegistry = new MainRegistry_UsdOnly(address(factory));
        oracleHub = new OracleHub();
        standardERC20PricingModule = new StandardERC20PricingModule_UsdOnly(
            address(mainRegistry),
            address(oracleHub),
            0
        );
        uniswapV3PricingModule =
        new UniswapV3PricingModule_UsdOnly(address(mainRegistry), address(oracleHub), deployerAddress, address(standardERC20PricingModule));

        account = new AccountV1();
        actionMultiCall = new ActionMultiCallV2();

        oracleHub.addOracle(compToUsdOracleInfo);
        oracleHub.addOracle(daiToUsdOracleInfo);
        oracleHub.addOracle(ethToUsdOracleInfo);
        oracleHub.addOracle(usdcToUsdOracleInfo);
        oracleHub.addOracle(cbethToEthToUsdOracleInfo);
        oracleHub.addOracle(rethToEthOracleInfo);

        mainRegistry.addBaseCurrency(ethBaseCurrencyInfo);
        mainRegistry.addBaseCurrency(usdcBaseCurrencyInfo);

        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(uniswapV3PricingModule));

        PricingModule_UsdOnly.RiskVarInput[] memory riskVarsComp_ = riskVarsComp;
        PricingModule_UsdOnly.RiskVarInput[] memory riskVarsDai_ = riskVarsDai;
        PricingModule_UsdOnly.RiskVarInput[] memory riskVarsEth_ = riskVarsEth;
        PricingModule_UsdOnly.RiskVarInput[] memory riskVarsUsdc_ = riskVarsUsdc;
        PricingModule_UsdOnly.RiskVarInput[] memory riskVarsCbeth_ = riskVarsCbeth;
        PricingModule_UsdOnly.RiskVarInput[] memory riskVarsReth_ = riskVarsReth;

        standardERC20PricingModule.addAsset(
            DeployAddresses.comp_base,
            oracleCompToUsdArr,
            riskVarsComp_,
            type(uint128).max //todo: change after risk analysis
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.dai_base,
            oracleDaiToUsdArr,
            riskVarsDai_,
            type(uint128).max //todo: change after risk analysis
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.weth_base,
            oracleEthToUsdArr,
            riskVarsEth_,
            type(uint128).max //todo: change after risk analysis
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.usdc_base,
            oracleUsdcToUsdArr,
            riskVarsUsdc_,
            type(uint128).max //todo: change after risk analysis
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.cbeth_base,
            oracleCbethToEthToUsdArr,
            riskVarsCbeth_,
            type(uint128).max //todo: change after risk analysis
        );
        standardERC20PricingModule.addAsset(
            DeployAddresses.reth_base,
            oracleRethToEthToUsdArr,
            riskVarsReth_,
            type(uint128).max //todo: change after risk analysis
        );

        factory.setNewAccountInfo(address(mainRegistry), address(account), DeployBytes.upgradeRoot1To1, "");

        mainRegistry.setAllowedAction(address(actionMultiCall), true);

        wethLendingPool.setAccountVersion(1, true);
        usdcLendingPool.setAccountVersion(1, true);

        wethLendingPool.setBorrowCap(uint128(2000 * 10 ** 18));
        usdcLendingPool.setBorrowCap(uint128(5_000_000 * 10 ** 6));

        vm.stopBroadcast();
    }
}
