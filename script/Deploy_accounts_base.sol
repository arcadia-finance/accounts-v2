/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses, DeployBytes, DeployRiskConstantsBase } from "./Constants/DeployConstants.sol";

import { BitPackingLib } from "../src/libraries/BitPackingLib.sol";
import { Factory } from "../src/Factory.sol";
import { AccountV1 } from "../src/accounts/AccountV1.sol";
import { Registry } from "../src/Registry.sol";
import { ChainlinkOracleModule } from "../src/oracle-modules/ChainlinkOracleModule.sol";
import { StandardERC20AssetModule } from "../src/asset-modules/StandardERC20AssetModule.sol";
import { AssetModule } from "../src/asset-modules/AbstractAssetModule.sol";
import { UniswapV3AssetModule } from "../src/asset-modules/UniswapV3/UniswapV3AssetModule.sol";

import { ActionMultiCall } from "../src/actions/MultiCall.sol";

import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { ERC20 } from "../lib/solmate/src/tokens/ERC20.sol";

contract ArcadiaAccountDeployment is Test {
    Factory internal factory;
    AccountV1 internal account;

    ERC20 internal comp;
    ERC20 internal dai;
    ERC20 internal weth;
    ERC20 internal usdc;
    ERC20 internal cbeth;
    ERC20 internal reth;

    Registry internal registry;
    StandardERC20AssetModule internal standardERC20AssetModule;
    UniswapV3AssetModule internal uniswapV3AssetModule;
    ChainlinkOracleModule internal chainlinkOM;
    ActionMultiCall internal actionMultiCall;

    ILendingPool internal wethLendingPool;
    ILendingPool internal usdcLendingPool;

    bool[] internal BA_TO_QA_SINGLE = new bool[](1);
    bool[] internal BA_TO_QA_DOUBLE = new bool[](2);

    uint80[] internal oracleCompToUsdArr = new uint80[](1);
    uint80[] internal oracleDaiToUsdArr = new uint80[](1);
    uint80[] internal oracleEthToUsdArr = new uint80[](1);
    uint80[] internal oracleUsdcToUsdArr = new uint80[](1);
    uint80[] internal oracleCbethToEthToUsdArr = new uint80[](2);
    uint80[] internal oracleRethToEthToUsdArr = new uint80[](2);

    uint80 internal oracleCompToUsdId;
    uint80 internal oracleDaiToUsdId;
    uint80 internal oracleEthToUsdId;
    uint80 internal oracleUsdcToUsdId;
    uint80 internal oracleCbethToEthId;
    uint80 internal oracleRethToEthId;

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
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        factory = Factory(0x38dB790e1894A5863387B43290c8340121e7Cd48); //todo: change after factory deploy
        wethLendingPool = ILendingPool(0xA04B08324745AEc82De30c3581c407BE63E764c8); //todo: change after LP deploy
        usdcLendingPool = ILendingPool(0x4d39409993dBe365c9AcaAe7c7e259C06FBFFa4A); //todo: change after LP deploy
        wethLendingPool.setRiskManager(deployerAddress);
        usdcLendingPool.setRiskManager(deployerAddress);

        registry = new Registry(address(factory));
        standardERC20AssetModule = new StandardERC20AssetModule(address(registry));
        uniswapV3AssetModule = new UniswapV3AssetModule(address(registry), DeployAddresses.uniswapV3PositionMgr_base);

        chainlinkOM = new ChainlinkOracleModule(address(registry));

        account = new AccountV1(address(factory));
        actionMultiCall = new ActionMultiCall();

        registry.addAssetModule(address(standardERC20AssetModule));
        registry.addAssetModule(address(uniswapV3AssetModule));

        registry.addOracleModule(address(chainlinkOM));

        oracleCompToUsdId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleCompToUsd_base, "COMP", "USD"));
        oracleDaiToUsdId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleDaiToUsd_base, "DAI", "USD"));
        oracleEthToUsdId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleEthToUsd_base, "ETH", "USD"));
        oracleUsdcToUsdId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleUsdcToUsd_base, "USDC", "USD"));
        oracleCbethToEthId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleCbethToEth_base, "CBETH", "ETH"));
        oracleRethToEthId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleRethToEth_base, "RETH", "ETH"));

        oracleCompToUsdArr[0] = oracleCompToUsdId;
        oracleDaiToUsdArr[0] = oracleDaiToUsdId;
        oracleEthToUsdArr[0] = oracleEthToUsdId;
        oracleUsdcToUsdArr[0] = oracleUsdcToUsdId;
        oracleCbethToEthToUsdArr[0] = oracleCbethToEthId;
        oracleCbethToEthToUsdArr[1] = oracleEthToUsdId;
        oracleRethToEthToUsdArr[0] = oracleRethToEthId;
        oracleRethToEthToUsdArr[1] = oracleEthToUsdId;

        standardERC20AssetModule.addAsset(
            DeployAddresses.comp_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleCompToUsdArr)
        );
        standardERC20AssetModule.addAsset(
            DeployAddresses.dai_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleDaiToUsdArr)
        );
        standardERC20AssetModule.addAsset(
            DeployAddresses.weth_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleEthToUsdArr)
        );
        standardERC20AssetModule.addAsset(
            DeployAddresses.usdc_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleUsdcToUsdArr)
        );
        standardERC20AssetModule.addAsset(
            DeployAddresses.cbeth_base, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleCbethToEthToUsdArr)
        );
        standardERC20AssetModule.addAsset(
            DeployAddresses.reth_base, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleRethToEthToUsdArr)
        );

        uniswapV3AssetModule.setProtocol();

        factory.setNewAccountInfo(address(registry), address(account), DeployBytes.upgradeRoot1To1, "");
        factory.changeGuardian(deployerAddress);

        registry.changeGuardian(deployerAddress);

        wethLendingPool.setAccountVersion(1, true);
        usdcLendingPool.setAccountVersion(1, true);

        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.comp_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.comp_collFact_1,
            DeployRiskConstantsBase.comp_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.dai_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.dai_collFact_1,
            DeployRiskConstantsBase.dai_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.weth_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.eth_collFact_1,
            DeployRiskConstantsBase.eth_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.usdc_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.usdc_collFact_1,
            DeployRiskConstantsBase.usdc_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.cbeth_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.cbeth_collFact_1,
            DeployRiskConstantsBase.cbeth_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.reth_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.reth_collFact_1,
            DeployRiskConstantsBase.reth_liqFact_1
        );

        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.comp_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.comp_collFact_2,
            DeployRiskConstantsBase.comp_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.dai_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.dai_collFact_2,
            DeployRiskConstantsBase.dai_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.weth_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.eth_collFact_2,
            DeployRiskConstantsBase.eth_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.usdc_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.usdc_collFact_2,
            DeployRiskConstantsBase.usdc_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.cbeth_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.cbeth_collFact_2,
            DeployRiskConstantsBase.cbeth_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.reth_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.reth_collFact_2,
            DeployRiskConstantsBase.reth_liqFact_2
        );

        registry.setMaxRecursiveCalls(address(usdcLendingPool), 5);
        registry.setMaxRecursiveCalls(address(wethLendingPool), 5);

        vm.stopBroadcast();
    }
}
