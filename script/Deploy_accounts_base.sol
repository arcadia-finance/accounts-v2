/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses, DeployNumbers, DeployBytes, DeployRiskConstantsBase } from "./Constants/DeployConstants.sol";

import { BitPackingLib } from "../src/libraries/BitPackingLib.sol";
import { Factory } from "../src/Factory.sol";
import { AccountV1 } from "../src/accounts/AccountV1.sol";
import { Registry } from "../src/Registry.sol";
import { ChainlinkOM } from "../src/oracle-modules/ChainlinkOM.sol";
import { ERC20PrimaryAM } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { AssetModule } from "../src/asset-modules/abstracts/AbstractAM.sol";
import { UniswapV3AM } from "../src/asset-modules/UniswapV3/UniswapV3AM.sol";
import { StargateAM } from "./../src/asset-modules/Stargate-Finance/StargateAM.sol";
import { StakedStargateAM } from "./../src/asset-modules/Stargate-Finance/StakedStargateAM.sol";

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
    ERC20 internal usdbc;
    ERC20 internal cbeth;
    ERC20 internal reth;
    ERC20 internal stg;

    Registry internal registry;

    ERC20PrimaryAM internal erc20PrimaryAM;
    UniswapV3AM internal uniswapV3AM;
    StargateAM internal stargateAM;
    StakedStargateAM internal stakedStargateAM;

    ChainlinkOM internal chainlinkOM;
    ActionMultiCall internal actionMultiCall;

    ILendingPool internal wethLendingPool;
    ILendingPool internal usdcLendingPool;

    bool[] internal BA_TO_QA_SINGLE = new bool[](1);
    bool[] internal BA_TO_QA_DOUBLE = new bool[](2);

    uint80[] internal oracleCompToUsdArr = new uint80[](1);
    uint80[] internal oracleDaiToUsdArr = new uint80[](1);
    uint80[] internal oracleEthToUsdArr = new uint80[](1);
    uint80[] internal oracleUsdcToUsdArr = new uint80[](1);
    uint80[] internal oracleUsdbcToUsdArr = new uint80[](1);
    uint80[] internal oracleCbethToEthToUsdArr = new uint80[](2);
    uint80[] internal oracleRethToEthToUsdArr = new uint80[](2);
    uint80[] internal oracleStgToUsdArr = new uint80[](1);

    uint80 internal oracleCompToUsdId;
    uint80 internal oracleDaiToUsdId;
    uint80 internal oracleEthToUsdId;
    uint80 internal oracleUsdcToUsdId;
    uint80 internal oracleUsdbcToUsdId;
    uint80 internal oracleCbethToEthId;
    uint80 internal oracleRethToEthId;
    uint80 internal oracleStgToUsdId;

    constructor() {
        // /*///////////////////////////////////////////////////////////////
        //                   ADDRESSES
        // ///////////////////////////////////////////////////////////////*/

        comp = ERC20(DeployAddresses.comp_base);
        dai = ERC20(DeployAddresses.dai_base);
        weth = ERC20(DeployAddresses.weth_base);
        usdc = ERC20(DeployAddresses.usdc_base);
        usdbc = ERC20(DeployAddresses.usdbc_base);
        cbeth = ERC20(DeployAddresses.cbeth_base);
        reth = ERC20(DeployAddresses.reth_base);
        stg = ERC20(DeployAddresses.stg_base);

        BA_TO_QA_SINGLE[0] = true;
        BA_TO_QA_DOUBLE[0] = true;
        BA_TO_QA_DOUBLE[1] = true;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        factory = Factory(0x38dB790e1894A5863387B43290c8340121e7Cd48); //todo: change after factory deploy
        wethLendingPool = ILendingPool(0xA04B08324745AEc82De30c3581c407BE63E764c8); //todo: change after LP deploy
        usdcLendingPool = ILendingPool(0xEda73DA39Aae3282DDC2Dc924c740574567FFabc); //todo: change after LP deploy
        wethLendingPool.setRiskManager(deployerAddress);
        usdcLendingPool.setRiskManager(deployerAddress);

        registry = new Registry(address(factory), DeployAddresses.sequencerUptimeOracle_base);

        chainlinkOM = new ChainlinkOM(address(registry));

        account = new AccountV1(address(factory));
        actionMultiCall = new ActionMultiCall();

        erc20PrimaryAM = new ERC20PrimaryAM(address(registry));

        registry.addAssetModule(address(erc20PrimaryAM));

        registry.addOracleModule(address(chainlinkOM));

        oracleCompToUsdId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleCompToUsd_base, "COMP", "USD", 100 days));
        oracleDaiToUsdId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleDaiToUsd_base, "DAI", "USD", 100 days));
        oracleEthToUsdId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleEthToUsd_base, "ETH", "USD", 100 days));
        oracleUsdcToUsdId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleUsdcToUsd_base, "USDC", "USD", 100 days));
        oracleCbethToEthId =
            uint80(chainlinkOM.addOracle(DeployAddresses.oracleCbethToEth_base, "CBETH", "ETH", 100 days));
        oracleRethToEthId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleRethToEth_base, "RETH", "ETH", 100 days));
        oracleStgToUsdId = uint80(chainlinkOM.addOracle(DeployAddresses.oracleStgToUsd_base, "STG", "USD", 100 days));

        oracleCompToUsdArr[0] = oracleCompToUsdId;
        oracleDaiToUsdArr[0] = oracleDaiToUsdId;
        oracleEthToUsdArr[0] = oracleEthToUsdId;
        oracleUsdcToUsdArr[0] = oracleUsdcToUsdId;
        oracleUsdbcToUsdArr[0] = oracleUsdcToUsdId;
        oracleCbethToEthToUsdArr[0] = oracleCbethToEthId;
        oracleCbethToEthToUsdArr[1] = oracleEthToUsdId;
        oracleRethToEthToUsdArr[0] = oracleRethToEthId;
        oracleRethToEthToUsdArr[1] = oracleEthToUsdId;
        oracleStgToUsdArr[0] = oracleStgToUsdId;

        erc20PrimaryAM.addAsset(DeployAddresses.comp_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleCompToUsdArr));
        erc20PrimaryAM.addAsset(DeployAddresses.dai_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleDaiToUsdArr));
        erc20PrimaryAM.addAsset(DeployAddresses.weth_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleEthToUsdArr));
        erc20PrimaryAM.addAsset(DeployAddresses.usdc_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleUsdcToUsdArr));
        erc20PrimaryAM.addAsset(DeployAddresses.usdbc_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleUsdbcToUsdArr));
        erc20PrimaryAM.addAsset(
            DeployAddresses.cbeth_base, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleCbethToEthToUsdArr)
        );
        erc20PrimaryAM.addAsset(DeployAddresses.reth_base, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleRethToEthToUsdArr));
        erc20PrimaryAM.addAsset(DeployAddresses.stg_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStgToUsdArr));

        uniswapV3AM = new UniswapV3AM(address(registry), DeployAddresses.uniswapV3PositionMgr_base);

        stargateAM = new StargateAM(address(registry), DeployAddresses.stargateFactory_base);
        stakedStargateAM = new StakedStargateAM(address(registry), DeployAddresses.stargateLpStakingTime_base);

        registry.addAssetModule(address(uniswapV3AM));
        registry.addAssetModule(address(stargateAM));
        registry.addAssetModule(address(stakedStargateAM));

        uniswapV3AM.setProtocol();

        stargateAM.addAsset(DeployNumbers.stargateUsdbcPoolId);

        stakedStargateAM.initialize();

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
            DeployAddresses.usdbc_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.usdbc_collFact_1,
            DeployRiskConstantsBase.usdbc_liqFact_1
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
            address(wethLendingPool),
            DeployAddresses.stg_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.stg_collFact_1,
            DeployRiskConstantsBase.stg_liqFact_1
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
            DeployAddresses.usdbc_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.usdbc_collFact_2,
            DeployRiskConstantsBase.usdbc_liqFact_2
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
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.stg_base,
            0,
            type(uint112).max,
            DeployRiskConstantsBase.stg_collFact_2,
            DeployRiskConstantsBase.stg_liqFact_2
        );

        registry.setRiskParametersOfDerivedAM(
            address(usdcLendingPool), address(uniswapV3AM), 15 * 10 ** 6 * 10 ** 18, 9800
        );
        registry.setRiskParametersOfDerivedAM(
            address(wethLendingPool), address(uniswapV3AM), 15 * 10 ** 6 * 10 ** 18, 9800
        );
        registry.setRiskParametersOfDerivedAM(
            address(usdcLendingPool), address(stargateAM), 15 * 10 ** 6 * 10 ** 18, 9700
        );
        registry.setRiskParametersOfDerivedAM(
            address(wethLendingPool), address(stargateAM), 15 * 10 ** 6 * 10 ** 18, 9700
        );
        registry.setRiskParametersOfDerivedAM(
            address(usdcLendingPool), address(stakedStargateAM), 15 * 10 ** 6 * 10 ** 18, 9800
        );
        registry.setRiskParametersOfDerivedAM(
            address(wethLendingPool), address(stakedStargateAM), 15 * 10 ** 6 * 10 ** 18, 9800
        );

        registry.setRiskParameters(address(usdcLendingPool), 0, 15 minutes, 5);
        registry.setRiskParameters(address(wethLendingPool), 0, 15 minutes, 5);

        vm.stopBroadcast();
    }
}
