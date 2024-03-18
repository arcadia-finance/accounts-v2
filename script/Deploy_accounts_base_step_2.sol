/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses, DeployNumbers, DeployRiskConstantsBase } from "./Constants/DeployConstants.sol";

import { Factory } from "../src/Factory.sol";
import { AccountV1 } from "../src/accounts/AccountV1.sol";
import { Registry } from "../src/Registry.sol";
import { ChainlinkOM } from "../src/oracle-modules/ChainlinkOM.sol";
import { ERC20PrimaryAM } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
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
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address protocolOwnerAddress = DeployAddresses.protocolOwner_base;

        assertEq(deployerAddress, protocolOwnerAddress);

        vm.startBroadcast(deployerPrivateKey);
        factory = Factory(0x38dB790e1894A5863387B43290c8340121e7Cd48); //todo: change after factory deploy
        wethLendingPool = ILendingPool(0xA04B08324745AEc82De30c3581c407BE63E764c8); //todo: change after LP deploy
        usdcLendingPool = ILendingPool(0xEda73DA39Aae3282DDC2Dc924c740574567FFabc); //todo: change after LP deploy
        // registry = Registry(); //todo: change after registry deploy
        // chainlinkOM = ChainlinkOM(); //todo: change after chainlinkOM deploy
        // account = AccountV1(); //todo: change after accountV1 deploy
        // actionMultiCall = ActionMultiCall(); //todo: change after actionMultiCall deploy
        // erc20PrimaryAM = ERC20PrimaryAM(); //todo: change after erc20PrimaryAM deploy
        // uniswapV3AM = UniswapV3AM(); //todo: change after uniswapV3AM deploy
        // stargateAM = StargateAM(); //todo: change after stargateAM deploy
        // stakedStargateAM = StakedStargateAM(); //todo: change after stakedStargateAM deploy

        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.comp_base,
            0,
            0,
            DeployRiskConstantsBase.comp_collFact_1,
            DeployRiskConstantsBase.comp_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.dai_base,
            0,
            uint112(1000 * 10 ** DeployNumbers.daiDecimals),
            DeployRiskConstantsBase.dai_collFact_1,
            DeployRiskConstantsBase.dai_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.weth_base,
            0,
            uint112(1000 * 10 ** DeployNumbers.daiDecimals),
            DeployRiskConstantsBase.eth_collFact_1,
            DeployRiskConstantsBase.eth_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.usdc_base,
            0,
            uint112(1000 * 10 ** DeployNumbers.usdcDecimals),
            DeployRiskConstantsBase.usdc_collFact_1,
            DeployRiskConstantsBase.usdc_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.usdbc_base,
            0,
            uint112(1000 * 10 ** DeployNumbers.usdbcDecimals),
            DeployRiskConstantsBase.usdbc_collFact_1,
            DeployRiskConstantsBase.usdbc_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.cbeth_base,
            0,
            uint112(1 * 10 ** DeployNumbers.cbethDecimals),
            DeployRiskConstantsBase.cbeth_collFact_1,
            DeployRiskConstantsBase.cbeth_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.reth_base,
            0,
            uint112(1 * 10 ** DeployNumbers.rethDecimals),
            DeployRiskConstantsBase.reth_collFact_1,
            DeployRiskConstantsBase.reth_liqFact_1
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.stg_base,
            0,
            uint112(1000 * 10 ** DeployNumbers.stgDecimals),
            DeployRiskConstantsBase.stg_collFact_1,
            DeployRiskConstantsBase.stg_liqFact_1
        );

        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.comp_base,
            0,
            0,
            DeployRiskConstantsBase.comp_collFact_2,
            DeployRiskConstantsBase.comp_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.dai_base,
            0,
            uint112(1000 * 10 ** DeployNumbers.daiDecimals),
            DeployRiskConstantsBase.dai_collFact_2,
            DeployRiskConstantsBase.dai_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.weth_base,
            0,
            uint112(1 * 10 ** DeployNumbers.wethDecimals),
            DeployRiskConstantsBase.eth_collFact_2,
            DeployRiskConstantsBase.eth_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.usdc_base,
            0,
            uint112(1000 * 10 ** DeployNumbers.usdcDecimals),
            DeployRiskConstantsBase.usdc_collFact_2,
            DeployRiskConstantsBase.usdc_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.usdbc_base,
            0,
            uint112(1000 * 10 ** DeployNumbers.usdbcDecimals),
            DeployRiskConstantsBase.usdbc_collFact_2,
            DeployRiskConstantsBase.usdbc_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.cbeth_base,
            0,
            uint112(1 * 10 ** DeployNumbers.cbethDecimals),
            DeployRiskConstantsBase.cbeth_collFact_2,
            DeployRiskConstantsBase.cbeth_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.reth_base,
            0,
            uint112(1 * 10 ** DeployNumbers.rethDecimals),
            DeployRiskConstantsBase.reth_collFact_2,
            DeployRiskConstantsBase.reth_liqFact_2
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.stg_base,
            0,
            uint112(1000 * 10 ** DeployNumbers.stgDecimals),
            DeployRiskConstantsBase.stg_collFact_2,
            DeployRiskConstantsBase.stg_liqFact_2
        );

        registry.setRiskParametersOfDerivedAM(address(usdcLendingPool), address(uniswapV3AM), 10_000 * 10 ** 18, 9800);
        registry.setRiskParametersOfDerivedAM(address(wethLendingPool), address(uniswapV3AM), 10_000 * 10 ** 18, 9800);
        registry.setRiskParametersOfDerivedAM(address(usdcLendingPool), address(stargateAM), 5000 * 10 ** 18, 9700);
        registry.setRiskParametersOfDerivedAM(address(wethLendingPool), address(stargateAM), 5000 * 10 ** 18, 9700);
        registry.setRiskParametersOfDerivedAM(
            address(usdcLendingPool), address(stakedStargateAM), 5000 * 10 ** 18, 9800
        );
        registry.setRiskParametersOfDerivedAM(
            address(wethLendingPool), address(stakedStargateAM), 5000 * 10 ** 18, 9800
        );

        registry.setRiskParameters(address(usdcLendingPool), 5, 15 minutes, 5);
        registry.setRiskParameters(address(wethLendingPool), 5, 15 minutes, 5);

        vm.stopBroadcast();
    }

    function xtest_deploy() public {
        address protocolOwnerAddress = DeployAddresses.protocolOwner_base;

        address[] memory assetAddresses = new address[](8);
        assetAddresses[0] = address(comp);
        assetAddresses[1] = address(dai);
        assetAddresses[2] = address(weth);
        assetAddresses[3] = address(usdc);
        assetAddresses[4] = address(usdbc);
        assetAddresses[5] = address(cbeth);
        assetAddresses[6] = address(reth);
        assetAddresses[7] = address(stg);

        uint256[] memory assetIds = new uint256[](8);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 0;
        assetIds[3] = 0;
        assetIds[4] = 0;
        assetIds[5] = 0;
        assetIds[6] = 0;
        assetIds[7] = 0;

        (uint16[] memory collateralFactors_weth, uint16[] memory liquidationFactors_weth) =
            registry.getRiskFactors(address(wethLendingPool), assetAddresses, assetIds);
        assertEq(collateralFactors_weth[0], DeployRiskConstantsBase.comp_collFact_1);
        assertEq(liquidationFactors_weth[0], DeployRiskConstantsBase.comp_liqFact_1);
        assertEq(collateralFactors_weth[1], DeployRiskConstantsBase.dai_collFact_1);
        assertEq(liquidationFactors_weth[1], DeployRiskConstantsBase.dai_liqFact_1);
        assertEq(collateralFactors_weth[2], DeployRiskConstantsBase.eth_collFact_1);
        assertEq(liquidationFactors_weth[2], DeployRiskConstantsBase.eth_liqFact_1);
        assertEq(collateralFactors_weth[3], DeployRiskConstantsBase.usdc_collFact_1);
        assertEq(liquidationFactors_weth[3], DeployRiskConstantsBase.usdc_liqFact_1);
        assertEq(collateralFactors_weth[4], DeployRiskConstantsBase.usdbc_collFact_1);
        assertEq(liquidationFactors_weth[4], DeployRiskConstantsBase.usdbc_liqFact_1);
        assertEq(collateralFactors_weth[5], DeployRiskConstantsBase.cbeth_collFact_1);
        assertEq(liquidationFactors_weth[5], DeployRiskConstantsBase.cbeth_liqFact_1);
        assertEq(collateralFactors_weth[6], DeployRiskConstantsBase.reth_collFact_1);
        assertEq(liquidationFactors_weth[6], DeployRiskConstantsBase.reth_liqFact_1);
        assertEq(collateralFactors_weth[7], DeployRiskConstantsBase.stg_collFact_1);
        assertEq(liquidationFactors_weth[7], DeployRiskConstantsBase.stg_liqFact_1);

        (uint16[] memory collateralFactors_usdc, uint16[] memory liquidationFactors_usdc) =
            registry.getRiskFactors(address(usdcLendingPool), assetAddresses, assetIds);
        assertEq(collateralFactors_usdc[0], DeployRiskConstantsBase.comp_collFact_2);
        assertEq(liquidationFactors_usdc[0], DeployRiskConstantsBase.comp_liqFact_2);
        assertEq(collateralFactors_usdc[1], DeployRiskConstantsBase.dai_collFact_2);
        assertEq(liquidationFactors_usdc[1], DeployRiskConstantsBase.dai_liqFact_2);
        assertEq(collateralFactors_usdc[2], DeployRiskConstantsBase.eth_collFact_2);
        assertEq(liquidationFactors_usdc[2], DeployRiskConstantsBase.eth_liqFact_2);
        assertEq(collateralFactors_usdc[3], DeployRiskConstantsBase.usdc_collFact_2);
        assertEq(liquidationFactors_usdc[3], DeployRiskConstantsBase.usdc_liqFact_2);
        assertEq(collateralFactors_usdc[4], DeployRiskConstantsBase.usdbc_collFact_2);
        assertEq(liquidationFactors_usdc[4], DeployRiskConstantsBase.usdbc_liqFact_2);
        assertEq(collateralFactors_usdc[5], DeployRiskConstantsBase.cbeth_collFact_2);
        assertEq(liquidationFactors_usdc[5], DeployRiskConstantsBase.cbeth_liqFact_2);
        assertEq(collateralFactors_usdc[6], DeployRiskConstantsBase.reth_collFact_2);
        assertEq(liquidationFactors_usdc[6], DeployRiskConstantsBase.reth_liqFact_2);
        assertEq(collateralFactors_usdc[7], DeployRiskConstantsBase.stg_collFact_2);
        assertEq(liquidationFactors_usdc[7], DeployRiskConstantsBase.stg_liqFact_2);

        (uint128 minUsdValue_weth, uint64 gracePeriod_weth, uint64 maxRecursiveCalls_weth) =
            registry.riskParams(address(wethLendingPool));
        assertEq(minUsdValue_weth, 5);
        assertEq(gracePeriod_weth, 15 minutes);
        assertEq(maxRecursiveCalls_weth, 5);

        (uint128 minUsdValue_usdc, uint64 gracePeriod_usdc, uint64 maxRecursiveCalls_usdc) =
            registry.riskParams(address(usdcLendingPool));
        assertEq(minUsdValue_usdc, 5);
        assertEq(gracePeriod_usdc, 15 minutes);
        assertEq(maxRecursiveCalls_usdc, 5);

        // Registry.RiskParameters memory riskParameters_ = registry.riskParams(address(usdcLendingPool));
        // assertEq(riskParameters_.minUsdValue, 5);
        // assertEq(riskParameters_.gracePeriod, 15 minutes);
        // assertEq(riskParameters_.maxRecursiveCalls, 5);

        // UniswapV3AM.RiskParameters memory riskParameters_v3AM = uniswapV3AM.riskParams(address(wethLendingPool));
        //todo: continue checks
    }
}
