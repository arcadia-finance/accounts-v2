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

contract ArcadiaAccountDeploymentStep2 is Test {
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

        factory = Factory(0xDa14Fdd72345c4d2511357214c5B89A919768e59);
        wethLendingPool = ILendingPool(0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2);
        usdcLendingPool = ILendingPool(0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1);
        registry = Registry(0xd0690557600eb8Be8391D1d97346e2aab5300d5f);
        chainlinkOM = ChainlinkOM(0x6a5485E3ce6913890ae5e8bDc08a868D432eEB31);
        account = AccountV1(0xbea2B6d45ACaF62385877D835970a0788719cAe1);
        actionMultiCall = ActionMultiCall(0x05B9aB82e34688ecC87408E0821d9779c3Bfa5A3);
        erc20PrimaryAM = ERC20PrimaryAM(0xfBecEaFC96ed6fc800753d3eE6782b6F9a60Eed7);
        uniswapV3AM = UniswapV3AM(0x21bd524cC54CA78A7c48254d4676184f781667dC);
        stargateAM = StargateAM(0x20f7903290bF98716B62Dc1c9DA634291b8cfeD4);
        stakedStargateAM = StakedStargateAM(0xae909e19fd13C01c28d5Ee439D403920CF7f9Eea);

        vm.startBroadcast(deployerPrivateKey);
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.comp_base,
            0,
            DeployRiskConstantsBase.comp_exposure_eth,
            DeployRiskConstantsBase.comp_collFact_eth,
            DeployRiskConstantsBase.comp_liqFact_eth
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.dai_base,
            0,
            DeployRiskConstantsBase.dai_exposure_eth,
            DeployRiskConstantsBase.dai_collFact_eth,
            DeployRiskConstantsBase.dai_liqFact_eth
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.weth_base,
            0,
            DeployRiskConstantsBase.eth_exposure_eth,
            DeployRiskConstantsBase.eth_collFact_eth,
            DeployRiskConstantsBase.eth_liqFact_eth
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.usdc_base,
            0,
            DeployRiskConstantsBase.usdc_exposure_eth,
            DeployRiskConstantsBase.usdc_collFact_eth,
            DeployRiskConstantsBase.usdc_liqFact_eth
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.usdbc_base,
            0,
            DeployRiskConstantsBase.usdbc_exposure_eth,
            DeployRiskConstantsBase.usdbc_collFact_eth,
            DeployRiskConstantsBase.usdbc_liqFact_eth
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.cbeth_base,
            0,
            DeployRiskConstantsBase.cbeth_exposure_eth,
            DeployRiskConstantsBase.cbeth_collFact_eth,
            DeployRiskConstantsBase.cbeth_liqFact_eth
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.reth_base,
            0,
            DeployRiskConstantsBase.reth_exposure_eth,
            DeployRiskConstantsBase.reth_collFact_eth,
            DeployRiskConstantsBase.reth_liqFact_eth
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.stg_base,
            0,
            DeployRiskConstantsBase.stg_exposure_eth,
            DeployRiskConstantsBase.stg_collFact_eth,
            DeployRiskConstantsBase.stg_liqFact_eth
        );

        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.comp_base,
            0,
            DeployRiskConstantsBase.comp_exposure_usdc,
            DeployRiskConstantsBase.comp_collFact_usdc,
            DeployRiskConstantsBase.comp_liqFact_usdc
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.dai_base,
            0,
            DeployRiskConstantsBase.dai_exposure_usdc,
            DeployRiskConstantsBase.dai_collFact_usdc,
            DeployRiskConstantsBase.dai_liqFact_usdc
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.weth_base,
            0,
            DeployRiskConstantsBase.eth_exposure_usdc,
            DeployRiskConstantsBase.eth_collFact_usdc,
            DeployRiskConstantsBase.eth_liqFact_usdc
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.usdc_base,
            0,
            DeployRiskConstantsBase.usdc_exposure_usdc,
            DeployRiskConstantsBase.usdc_collFact_usdc,
            DeployRiskConstantsBase.usdc_liqFact_usdc
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.usdbc_base,
            0,
            DeployRiskConstantsBase.usdbc_exposure_usdc,
            DeployRiskConstantsBase.usdbc_collFact_usdc,
            DeployRiskConstantsBase.usdbc_liqFact_usdc
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.cbeth_base,
            0,
            DeployRiskConstantsBase.cbeth_exposure_usdc,
            DeployRiskConstantsBase.cbeth_collFact_usdc,
            DeployRiskConstantsBase.cbeth_liqFact_usdc
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.reth_base,
            0,
            DeployRiskConstantsBase.reth_exposure_usdc,
            DeployRiskConstantsBase.reth_collFact_usdc,
            DeployRiskConstantsBase.reth_liqFact_usdc
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.stg_base,
            0,
            DeployRiskConstantsBase.stg_exposure_usdc,
            DeployRiskConstantsBase.stg_collFact_usdc,
            DeployRiskConstantsBase.stg_liqFact_usdc
        );

        registry.setRiskParametersOfDerivedAM(
            address(usdcLendingPool),
            address(uniswapV3AM),
            DeployRiskConstantsBase.uniswapV3AM_exposure_usdc,
            DeployRiskConstantsBase.uniswapV3AM_riskFact_usdc
        );
        registry.setRiskParametersOfDerivedAM(
            address(wethLendingPool),
            address(uniswapV3AM),
            DeployRiskConstantsBase.uniswapV3AM_exposure_eth,
            DeployRiskConstantsBase.uniswapV3AM_riskFact_eth
        );
        registry.setRiskParametersOfDerivedAM(
            address(usdcLendingPool),
            address(stargateAM),
            DeployRiskConstantsBase.stargateAM_exposure_usdc,
            DeployRiskConstantsBase.stargateAM_riskFact_usdc
        );
        registry.setRiskParametersOfDerivedAM(
            address(wethLendingPool),
            address(stargateAM),
            DeployRiskConstantsBase.stargateAM_exposure_eth,
            DeployRiskConstantsBase.stargateAM_riskFact_eth
        );
        registry.setRiskParametersOfDerivedAM(
            address(usdcLendingPool),
            address(stakedStargateAM),
            DeployRiskConstantsBase.stakedStargateAM_exposure_usdc,
            DeployRiskConstantsBase.stakedStargateAM_riskFact_usdc
        );
        registry.setRiskParametersOfDerivedAM(
            address(wethLendingPool),
            address(stakedStargateAM),
            DeployRiskConstantsBase.stakedStargateAM_exposure_eth,
            DeployRiskConstantsBase.stakedStargateAM_riskFact_eth
        );

        registry.setRiskParameters(
            address(usdcLendingPool),
            DeployRiskConstantsBase.minUsdValue_usdc,
            DeployRiskConstantsBase.gracePeriod_usdc,
            DeployRiskConstantsBase.maxRecursiveCalls_usdc
        );
        registry.setRiskParameters(
            address(wethLendingPool),
            DeployRiskConstantsBase.minUsdValue_eth,
            DeployRiskConstantsBase.gracePeriod_eth,
            DeployRiskConstantsBase.maxRecursiveCalls_eth
        );

        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
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
        assertEq(collateralFactors_weth[0], DeployRiskConstantsBase.comp_collFact_eth);
        assertEq(liquidationFactors_weth[0], DeployRiskConstantsBase.comp_liqFact_eth);
        assertEq(collateralFactors_weth[1], DeployRiskConstantsBase.dai_collFact_eth);
        assertEq(liquidationFactors_weth[1], DeployRiskConstantsBase.dai_liqFact_eth);
        assertEq(collateralFactors_weth[2], DeployRiskConstantsBase.eth_collFact_eth);
        assertEq(liquidationFactors_weth[2], DeployRiskConstantsBase.eth_liqFact_eth);
        assertEq(collateralFactors_weth[3], DeployRiskConstantsBase.usdc_collFact_eth);
        assertEq(liquidationFactors_weth[3], DeployRiskConstantsBase.usdc_liqFact_eth);
        assertEq(collateralFactors_weth[4], DeployRiskConstantsBase.usdbc_collFact_eth);
        assertEq(liquidationFactors_weth[4], DeployRiskConstantsBase.usdbc_liqFact_eth);
        assertEq(collateralFactors_weth[5], DeployRiskConstantsBase.cbeth_collFact_eth);
        assertEq(liquidationFactors_weth[5], DeployRiskConstantsBase.cbeth_liqFact_eth);
        assertEq(collateralFactors_weth[6], DeployRiskConstantsBase.reth_collFact_eth);
        assertEq(liquidationFactors_weth[6], DeployRiskConstantsBase.reth_liqFact_eth);
        assertEq(collateralFactors_weth[7], DeployRiskConstantsBase.stg_collFact_eth);
        assertEq(liquidationFactors_weth[7], DeployRiskConstantsBase.stg_liqFact_eth);

        (uint16[] memory collateralFactors_usdc, uint16[] memory liquidationFactors_usdc) =
            registry.getRiskFactors(address(usdcLendingPool), assetAddresses, assetIds);
        assertEq(collateralFactors_usdc[0], DeployRiskConstantsBase.comp_collFact_usdc);
        assertEq(liquidationFactors_usdc[0], DeployRiskConstantsBase.comp_liqFact_usdc);
        assertEq(collateralFactors_usdc[1], DeployRiskConstantsBase.dai_collFact_usdc);
        assertEq(liquidationFactors_usdc[1], DeployRiskConstantsBase.dai_liqFact_usdc);
        assertEq(collateralFactors_usdc[2], DeployRiskConstantsBase.eth_collFact_usdc);
        assertEq(liquidationFactors_usdc[2], DeployRiskConstantsBase.eth_liqFact_usdc);
        assertEq(collateralFactors_usdc[3], DeployRiskConstantsBase.usdc_collFact_usdc);
        assertEq(liquidationFactors_usdc[3], DeployRiskConstantsBase.usdc_liqFact_usdc);
        assertEq(collateralFactors_usdc[4], DeployRiskConstantsBase.usdbc_collFact_usdc);
        assertEq(liquidationFactors_usdc[4], DeployRiskConstantsBase.usdbc_liqFact_usdc);
        assertEq(collateralFactors_usdc[5], DeployRiskConstantsBase.cbeth_collFact_usdc);
        assertEq(liquidationFactors_usdc[5], DeployRiskConstantsBase.cbeth_liqFact_usdc);
        assertEq(collateralFactors_usdc[6], DeployRiskConstantsBase.reth_collFact_usdc);
        assertEq(liquidationFactors_usdc[6], DeployRiskConstantsBase.reth_liqFact_usdc);
        assertEq(collateralFactors_usdc[7], DeployRiskConstantsBase.stg_collFact_usdc);
        assertEq(liquidationFactors_usdc[7], DeployRiskConstantsBase.stg_liqFact_usdc);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(comp)));
        (, uint112 exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.comp_exposure_eth);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.comp_exposure_usdc);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(dai)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.dai_exposure_eth);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.dai_exposure_usdc);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(weth)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.eth_exposure_eth);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.eth_exposure_usdc);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(usdc)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.usdc_exposure_eth);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.usdc_exposure_usdc);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(usdbc)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.usdbc_exposure_eth);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.usdbc_exposure_usdc);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(cbeth)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.cbeth_exposure_eth);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.cbeth_exposure_usdc);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(reth)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.reth_exposure_eth);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.reth_exposure_usdc);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(stg)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.stg_exposure_eth);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, DeployRiskConstantsBase.stg_exposure_usdc);

        uint16 riskFactor;
        (, exposure, riskFactor) = uniswapV3AM.riskParams(address(wethLendingPool));
        assertEq(exposure, DeployRiskConstantsBase.uniswapV3AM_exposure_eth);
        assertEq(riskFactor, DeployRiskConstantsBase.uniswapV3AM_riskFact_eth);
        (, exposure, riskFactor) = uniswapV3AM.riskParams(address(usdcLendingPool));
        assertEq(exposure, DeployRiskConstantsBase.uniswapV3AM_exposure_usdc);
        assertEq(riskFactor, DeployRiskConstantsBase.uniswapV3AM_riskFact_usdc);
        (, exposure, riskFactor) = stargateAM.riskParams(address(wethLendingPool));
        assertEq(exposure, DeployRiskConstantsBase.stargateAM_exposure_eth);
        assertEq(riskFactor, DeployRiskConstantsBase.stargateAM_riskFact_eth);
        (, exposure, riskFactor) = stargateAM.riskParams(address(usdcLendingPool));
        assertEq(exposure, DeployRiskConstantsBase.stargateAM_exposure_usdc);
        assertEq(riskFactor, DeployRiskConstantsBase.stargateAM_riskFact_usdc);
        (, exposure, riskFactor) = stakedStargateAM.riskParams(address(wethLendingPool));
        assertEq(exposure, DeployRiskConstantsBase.stakedStargateAM_exposure_eth);
        assertEq(riskFactor, DeployRiskConstantsBase.stakedStargateAM_riskFact_eth);
        (, exposure, riskFactor) = stakedStargateAM.riskParams(address(usdcLendingPool));
        assertEq(exposure, DeployRiskConstantsBase.stakedStargateAM_exposure_usdc);
        assertEq(riskFactor, DeployRiskConstantsBase.stakedStargateAM_riskFact_usdc);

        (uint128 minUsdValue_weth, uint64 gracePeriod_weth, uint64 maxRecursiveCalls_weth) =
            registry.riskParams(address(wethLendingPool));
        assertEq(minUsdValue_weth, DeployRiskConstantsBase.minUsdValue_eth);
        assertEq(gracePeriod_weth, DeployRiskConstantsBase.gracePeriod_eth);
        assertEq(maxRecursiveCalls_weth, DeployRiskConstantsBase.maxRecursiveCalls_eth);

        (uint128 minUsdValue_usdc, uint64 gracePeriod_usdc, uint64 maxRecursiveCalls_usdc) =
            registry.riskParams(address(usdcLendingPool));
        assertEq(minUsdValue_usdc, DeployRiskConstantsBase.minUsdValue_usdc);
        assertEq(gracePeriod_usdc, DeployRiskConstantsBase.gracePeriod_usdc);
        assertEq(maxRecursiveCalls_usdc, DeployRiskConstantsBase.maxRecursiveCalls_usdc);
    }
}
