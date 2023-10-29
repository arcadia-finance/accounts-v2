/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses, DeployNumbers, DeployBytes, DeployRiskConstantsBase } from "./Constants/DeployConstants.sol";

import { Factory } from "../src/Factory.sol";
import { AccountV1 } from "../src/AccountV1.sol";
import { MainRegistry } from "../src/MainRegistry.sol";
import { StandardERC20PricingModule } from "../src/pricing-modules/StandardERC20PricingModule.sol";
import { PricingModule } from "../src/pricing-modules/AbstractPricingModule.sol";
import { UniswapV3PricingModule } from "../src/pricing-modules/UniswapV3/UniswapV3PricingModule.sol";
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
    MainRegistry public mainRegistry;
    StandardERC20PricingModule public standardERC20PricingModule;
    UniswapV3PricingModule public uniswapV3PricingModule;
    ActionMultiCallV2 public actionMultiCall;

    ILendingPool public wethLendingPool;
    ILendingPool public usdcLendingPool;

    address[] public oracleCompToUsdArr = new address[](1);
    address[] public oracleDaiToUsdArr = new address[](1);
    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleUsdcToUsdArr = new address[](1);
    address[] public oracleCbethToEthToUsdArr = new address[](2);
    address[] public oracleRethToEthToUsdArr = new address[](2);

    OracleHub.OracleInformation public compToUsdOracleInfo;
    OracleHub.OracleInformation public daiToUsdOracleInfo;
    OracleHub.OracleInformation public ethToUsdOracleInfo;
    OracleHub.OracleInformation public usdcToUsdOracleInfo;
    OracleHub.OracleInformation public cbethToEthToUsdOracleInfo;
    OracleHub.OracleInformation public rethToEthOracleInfo;

    MainRegistry.BaseCurrencyInformation public usdBaseCurrencyInfo;
    MainRegistry.BaseCurrencyInformation public ethBaseCurrencyInfo;
    MainRegistry.BaseCurrencyInformation public usdcBaseCurrencyInfo;

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
            baseAsset: "COMP",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleCompToUsd_base,
            baseAssetAddress: DeployAddresses.comp_base,
            isActive: true
        });

        daiToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleDaiToUsdUnit),
            baseAsset: "DAI",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleDaiToUsd_base,
            baseAssetAddress: DeployAddresses.dai_base,
            isActive: true
        });

        ethToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            baseAsset: "ETH",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleEthToUsd_base,
            baseAssetAddress: DeployAddresses.weth_base,
            isActive: true
        });

        usdcToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            baseAsset: "USDC",
            quoteAsset: "USD",
            oracle: DeployAddresses.oracleUsdcToUsd_base,
            baseAssetAddress: DeployAddresses.usdc_base,
            isActive: true
        });

        cbethToEthToUsdOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleCbethToEthUnit),
            baseAsset: "CBETH",
            quoteAsset: "ETH",
            oracle: DeployAddresses.oracleCbethToEth_base,
            baseAssetAddress: DeployAddresses.cbeth_base,
            isActive: true
        });

        rethToEthOracleInfo = OracleHub.OracleInformation({
            oracleUnit: uint64(DeployNumbers.oracleRethToEthUnit),
            baseAsset: "RETH",
            quoteAsset: "ETH",
            oracle: DeployAddresses.oracleRethToEth_base,
            baseAssetAddress: DeployAddresses.reth_base,
            isActive: true
        });

        ethBaseCurrencyInfo = MainRegistry.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleEthToUsdUnit),
            assetAddress: DeployAddresses.weth_base,
            baseCurrencyToUsdOracle: DeployAddresses.oracleEthToUsd_base,
            baseCurrencyLabel: "wETH",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.wethDecimals))
        });

        usdcBaseCurrencyInfo = MainRegistry.BaseCurrencyInformation({
            baseCurrencyToUsdOracleUnit: uint64(DeployNumbers.oracleUsdcToUsdUnit),
            assetAddress: DeployAddresses.usdc_base,
            baseCurrencyToUsdOracle: DeployAddresses.oracleUsdcToUsd_base,
            baseCurrencyLabel: "USDC",
            baseCurrencyUnitCorrection: uint64(10 ** (18 - DeployNumbers.usdcDecimals))
        });

        /*///////////////////////////////////////////////////////////////
                            RISK VARS
        ///////////////////////////////////////////////////////////////*/

        // ToDo: Refactor riskvars in Arcadia Lending?
        // riskVarsComp.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 0,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.comp_collFact_1,
        //         liquidationFactor: DeployRiskConstantsBase.comp_liqFact_1
        //     })
        // );
        // riskVarsComp.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 1,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.comp_collFact_2,
        //         liquidationFactor: DeployRiskConstantsBase.comp_liqFact_2
        //     })
        // );

        // riskVarsDai.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 0,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.dai_collFact_1,
        //         liquidationFactor: DeployRiskConstantsBase.dai_liqFact_1
        //     })
        // );
        // riskVarsDai.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 1,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.dai_collFact_2,
        //         liquidationFactor: DeployRiskConstantsBase.dai_liqFact_2
        //     })
        // );

        // riskVarsEth.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 0,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.eth_collFact_1,
        //         liquidationFactor: DeployRiskConstantsBase.eth_liqFact_1
        //     })
        // );
        // riskVarsEth.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 1,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.eth_collFact_2,
        //         liquidationFactor: DeployRiskConstantsBase.eth_liqFact_2
        //     })
        // );

        // riskVarsUsdc.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 0,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.usdc_collFact_1,
        //         liquidationFactor: DeployRiskConstantsBase.usdc_liqFact_1
        //     })
        // );
        // riskVarsUsdc.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 1,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.usdc_collFact_2,
        //         liquidationFactor: DeployRiskConstantsBase.usdc_liqFact_2
        //     })
        // );

        // riskVarsCbeth.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 0,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.cbeth_collFact_1,
        //         liquidationFactor: DeployRiskConstantsBase.cbeth_liqFact_1
        //     })
        // );
        // riskVarsCbeth.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 1,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.cbeth_collFact_2,
        //         liquidationFactor: DeployRiskConstantsBase.cbeth_liqFact_2
        //     })
        // );

        // riskVarsReth.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 0,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.reth_collFact_1,
        //         liquidationFactor: DeployRiskConstantsBase.reth_liqFact_1
        //     })
        // );
        // riskVarsReth.push(
        //     PricingModule.RiskVarInput({
        //         baseCurrency: 1,
        //         asset: address(0),
        //         collateralFactor: DeployRiskConstantsBase.reth_collFact_2,
        //         liquidationFactor: DeployRiskConstantsBase.reth_liqFact_2
        //     })
        // );
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        factory = Factory(0x38dB790e1894A5863387B43290c8340121e7Cd48); //todo: change after factory deploy
        wethLendingPool = ILendingPool(0xA04B08324745AEc82De30c3581c407BE63E764c8); //todo: change after LP deploy
        usdcLendingPool = ILendingPool(0x4d39409993dBe365c9AcaAe7c7e259C06FBFFa4A); //todo: change after LP deploy

        mainRegistry = new MainRegistry(address(factory));
        oracleHub = new OracleHub();
        standardERC20PricingModule = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub)        );
        uniswapV3PricingModule =
            new UniswapV3PricingModule(address(mainRegistry), DeployAddresses.uniswapV3PositionMgr_base);

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

        standardERC20PricingModule.addAsset(DeployAddresses.comp_base, oracleCompToUsdArr);
        standardERC20PricingModule.addAsset(DeployAddresses.dai_base, oracleDaiToUsdArr);
        standardERC20PricingModule.addAsset(DeployAddresses.weth_base, oracleEthToUsdArr);
        standardERC20PricingModule.addAsset(DeployAddresses.usdc_base, oracleUsdcToUsdArr);
        standardERC20PricingModule.addAsset(DeployAddresses.cbeth_base, oracleCbethToEthToUsdArr);
        standardERC20PricingModule.addAsset(DeployAddresses.reth_base, oracleRethToEthToUsdArr);

        factory.setNewAccountInfo(address(mainRegistry), address(account), DeployBytes.upgradeRoot1To1, "");
        factory.changeGuardian(deployerAddress);

        mainRegistry.setAllowedAction(address(actionMultiCall), true);
        mainRegistry.changeGuardian(deployerAddress);

        wethLendingPool.setAccountVersion(1, true);
        usdcLendingPool.setAccountVersion(1, true);

        wethLendingPool.setBorrowCap(uint128(2000 * 10 ** 18));
        usdcLendingPool.setBorrowCap(uint128(5_000_000 * 10 ** 6));

        vm.stopBroadcast();
    }
}
