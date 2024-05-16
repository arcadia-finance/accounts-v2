/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";
import { RiskParameters, ArcadiaSafes, PrimaryAssets } from "./utils/Constants.sol";

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

        comp = ERC20(PrimaryAssets.COMP);
        dai = ERC20(PrimaryAssets.DAI);
        weth = ERC20(PrimaryAssets.WETH);
        usdc = ERC20(PrimaryAssets.USDC);
        usdbc = ERC20(PrimaryAssets.USDBC);
        cbeth = ERC20(PrimaryAssets.CBETH);
        reth = ERC20(PrimaryAssets.RETH);
        stg = ERC20(PrimaryAssets.STG);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address protocolOwnerAddress = ArcadiaSafes.OWNER;
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
            PrimaryAssets.COMP,
            0,
            RiskParameters.EXPOSURE_COMP_WETH,
            RiskParameters.COL_FAC_COMP_WETH,
            RiskParameters.LIQ_FAC_COMP_WETH
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            PrimaryAssets.DAI,
            0,
            RiskParameters.EXPOSURE_DAI_WETH,
            RiskParameters.COL_FAC_DAI_WETH,
            RiskParameters.LIQ_FAC_DAI_WETH
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            PrimaryAssets.WETH,
            0,
            RiskParameters.EXPOSURE_WETH_WETH,
            RiskParameters.COL_FAC_WETH_WETH,
            RiskParameters.LIQ_FAC_WETH_WETH
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            PrimaryAssets.USDC,
            0,
            RiskParameters.EXPOSURE_USDC_WETH,
            RiskParameters.COL_FAC_USDC_WETH,
            RiskParameters.LIQ_FAC_USDC_WETH
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            PrimaryAssets.USDBC,
            0,
            RiskParameters.EXPOSURE_USDBC_WETH,
            RiskParameters.COL_FAC_USDBC_WETH,
            RiskParameters.LIQ_FAC_USDBC_WETH
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            PrimaryAssets.CBETH,
            0,
            RiskParameters.EXPOSURE_CBETH_WETH,
            RiskParameters.COL_FAC_CBETH_WETH,
            RiskParameters.LIQ_FAC_CBETH_WETH
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            PrimaryAssets.RETH,
            0,
            RiskParameters.EXPOSURE_RETH_WETH,
            RiskParameters.COL_FAC_RETH_WETH,
            RiskParameters.LIQ_FAC_RETH_WETH
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            PrimaryAssets.STG,
            0,
            RiskParameters.EXPOSURE_STG_WETH,
            RiskParameters.COL_FAC_STG_WETH,
            RiskParameters.LIQ_FAC_STG_WETH
        );

        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            PrimaryAssets.COMP,
            0,
            RiskParameters.EXPOSURE_COMP_USDC,
            RiskParameters.COL_FAC_COMP_USDC,
            RiskParameters.LIQ_FAC_COMP_USDC
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            PrimaryAssets.DAI,
            0,
            RiskParameters.EXPOSURE_DAI_USDC,
            RiskParameters.COL_FAC_DAI_USDC,
            RiskParameters.LIQ_FAC_DAI_USDC
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            PrimaryAssets.WETH,
            0,
            RiskParameters.EXPOSURE_WETH_USDC,
            RiskParameters.COL_FAC_WETH_USDC,
            RiskParameters.LIQ_FAC_WETH_USDC
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            PrimaryAssets.USDC,
            0,
            RiskParameters.EXPOSURE_USDC_USDC,
            RiskParameters.COL_FAC_USDC_USDC,
            RiskParameters.LIQ_FAC_USDC_USDC
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            PrimaryAssets.USDBC,
            0,
            RiskParameters.EXPOSURE_USDBC_USDC,
            RiskParameters.COL_FAC_USDBC_USDC,
            RiskParameters.LIQ_FAC_USDBC_USDC
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            PrimaryAssets.CBETH,
            0,
            RiskParameters.EXPOSURE_CBETH_USDC,
            RiskParameters.COL_FAC_CBETH_USDC,
            RiskParameters.LIQ_FAC_CBETH_USDC
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            PrimaryAssets.RETH,
            0,
            RiskParameters.EXPOSURE_RETH_USDC,
            RiskParameters.COL_FAC_RETH_USDC,
            RiskParameters.LIQ_FAC_RETH_USDC
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            PrimaryAssets.STG,
            0,
            RiskParameters.EXPOSURE_STG_USDC,
            RiskParameters.COL_FAC_STG_USDC,
            RiskParameters.LIQ_FAC_STG_USDC
        );

        registry.setRiskParametersOfDerivedAM(
            address(usdcLendingPool),
            address(uniswapV3AM),
            RiskParameters.EXPOSURE_UNISWAPV3_AM_USDC,
            RiskParameters.RISK_FAC_UNISWAPV3_AM_USDC
        );
        registry.setRiskParametersOfDerivedAM(
            address(wethLendingPool),
            address(uniswapV3AM),
            RiskParameters.EXPOSURE_UNISWAPV3_AM_WETH,
            RiskParameters.RISK_FAC_UNISWAPV3_AM_WETH
        );
        registry.setRiskParametersOfDerivedAM(
            address(usdcLendingPool),
            address(stargateAM),
            RiskParameters.EXPOSURE_STARGATE_AM_USDC,
            RiskParameters.RISK_FAC_STARGATE_AM_USDC
        );
        registry.setRiskParametersOfDerivedAM(
            address(wethLendingPool),
            address(stargateAM),
            RiskParameters.EXPOSURE_STARGATE_AM_WETH,
            RiskParameters.RISK_FAC_STARGATE_AM_WETH
        );
        registry.setRiskParametersOfDerivedAM(
            address(usdcLendingPool),
            address(stakedStargateAM),
            RiskParameters.EXPOSURE_STAKED_STARGATE_AM_USDC,
            RiskParameters.RISK_FAC_STAKED_STARGATE_AM_USDC
        );
        registry.setRiskParametersOfDerivedAM(
            address(wethLendingPool),
            address(stakedStargateAM),
            RiskParameters.EXPOSURE_STAKED_STARGATE_AM_WETH,
            RiskParameters.RISK_FAC_STAKED_STARGATE_AM_WETH
        );

        registry.setRiskParameters(
            address(usdcLendingPool),
            RiskParameters.MIN_USD_VALUE_USDC,
            RiskParameters.GRACE_PERIOD_USDC,
            RiskParameters.MAX_RECURSIVE_CALLS_USDC
        );
        registry.setRiskParameters(
            address(wethLendingPool),
            RiskParameters.MIN_USD_VALUE_WETH,
            RiskParameters.GRACE_PERIOD_WETH,
            RiskParameters.MAX_RECURSIVE_CALLS_WETH
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
        assertEq(collateralFactors_weth[0], RiskParameters.COL_FAC_COMP_WETH);
        assertEq(liquidationFactors_weth[0], RiskParameters.LIQ_FAC_COMP_WETH);
        assertEq(collateralFactors_weth[1], RiskParameters.COL_FAC_DAI_WETH);
        assertEq(liquidationFactors_weth[1], RiskParameters.LIQ_FAC_DAI_WETH);
        assertEq(collateralFactors_weth[2], RiskParameters.COL_FAC_WETH_WETH);
        assertEq(liquidationFactors_weth[2], RiskParameters.LIQ_FAC_WETH_WETH);
        assertEq(collateralFactors_weth[3], RiskParameters.COL_FAC_USDC_WETH);
        assertEq(liquidationFactors_weth[3], RiskParameters.LIQ_FAC_USDC_WETH);
        assertEq(collateralFactors_weth[4], RiskParameters.COL_FAC_USDBC_WETH);
        assertEq(liquidationFactors_weth[4], RiskParameters.LIQ_FAC_USDBC_WETH);
        assertEq(collateralFactors_weth[5], RiskParameters.COL_FAC_CBETH_WETH);
        assertEq(liquidationFactors_weth[5], RiskParameters.LIQ_FAC_CBETH_WETH);
        assertEq(collateralFactors_weth[6], RiskParameters.COL_FAC_RETH_WETH);
        assertEq(liquidationFactors_weth[6], RiskParameters.LIQ_FAC_RETH_WETH);
        assertEq(collateralFactors_weth[7], RiskParameters.COL_FAC_STG_WETH);
        assertEq(liquidationFactors_weth[7], RiskParameters.LIQ_FAC_STG_WETH);

        (uint16[] memory collateralFactors_usdc, uint16[] memory liquidationFactors_usdc) =
            registry.getRiskFactors(address(usdcLendingPool), assetAddresses, assetIds);
        assertEq(collateralFactors_usdc[0], RiskParameters.COL_FAC_COMP_USDC);
        assertEq(liquidationFactors_usdc[0], RiskParameters.LIQ_FAC_COMP_USDC);
        assertEq(collateralFactors_usdc[1], RiskParameters.COL_FAC_DAI_USDC);
        assertEq(liquidationFactors_usdc[1], RiskParameters.LIQ_FAC_DAI_USDC);
        assertEq(collateralFactors_usdc[2], RiskParameters.COL_FAC_WETH_USDC);
        assertEq(liquidationFactors_usdc[2], RiskParameters.LIQ_FAC_WETH_USDC);
        assertEq(collateralFactors_usdc[3], RiskParameters.COL_FAC_USDC_USDC);
        assertEq(liquidationFactors_usdc[3], RiskParameters.LIQ_FAC_USDC_USDC);
        assertEq(collateralFactors_usdc[4], RiskParameters.COL_FAC_USDBC_USDC);
        assertEq(liquidationFactors_usdc[4], RiskParameters.LIQ_FAC_USDBC_USDC);
        assertEq(collateralFactors_usdc[5], RiskParameters.COL_FAC_CBETH_USDC);
        assertEq(liquidationFactors_usdc[5], RiskParameters.LIQ_FAC_CBETH_USDC);
        assertEq(collateralFactors_usdc[6], RiskParameters.COL_FAC_RETH_USDC);
        assertEq(liquidationFactors_usdc[6], RiskParameters.LIQ_FAC_RETH_USDC);
        assertEq(collateralFactors_usdc[7], RiskParameters.COL_FAC_STG_USDC);
        assertEq(liquidationFactors_usdc[7], RiskParameters.LIQ_FAC_STG_USDC);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(comp)));
        (, uint112 exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_COMP_WETH);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_COMP_USDC);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(dai)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_DAI_WETH);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_DAI_USDC);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(weth)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_WETH_WETH);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_WETH_USDC);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(usdc)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_USDC_WETH);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_USDC_USDC);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(usdbc)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_USDBC_WETH);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_USDBC_USDC);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(cbeth)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_CBETH_WETH);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_CBETH_USDC);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(reth)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_RETH_WETH);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_RETH_USDC);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(stg)));
        (, exposure,,) = erc20PrimaryAM.riskParams(address(wethLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_STG_WETH);
        (, exposure,,) = erc20PrimaryAM.riskParams(address(usdcLendingPool), assetKey);
        assertEq(exposure, RiskParameters.EXPOSURE_STG_USDC);

        uint16 riskFactor;
        (, exposure, riskFactor) = uniswapV3AM.riskParams(address(wethLendingPool));
        assertEq(exposure, RiskParameters.EXPOSURE_UNISWAPV3_AM_WETH);
        assertEq(riskFactor, RiskParameters.RISK_FAC_UNISWAPV3_AM_WETH);
        (, exposure, riskFactor) = uniswapV3AM.riskParams(address(usdcLendingPool));
        assertEq(exposure, RiskParameters.EXPOSURE_UNISWAPV3_AM_USDC);
        assertEq(riskFactor, RiskParameters.RISK_FAC_UNISWAPV3_AM_USDC);
        (, exposure, riskFactor) = stargateAM.riskParams(address(wethLendingPool));
        assertEq(exposure, RiskParameters.EXPOSURE_STARGATE_AM_WETH);
        assertEq(riskFactor, RiskParameters.RISK_FAC_STARGATE_AM_WETH);
        (, exposure, riskFactor) = stargateAM.riskParams(address(usdcLendingPool));
        assertEq(exposure, RiskParameters.EXPOSURE_STARGATE_AM_USDC);
        assertEq(riskFactor, RiskParameters.RISK_FAC_STARGATE_AM_USDC);
        (, exposure, riskFactor) = stakedStargateAM.riskParams(address(wethLendingPool));
        assertEq(exposure, RiskParameters.EXPOSURE_STAKED_STARGATE_AM_WETH);
        assertEq(riskFactor, RiskParameters.RISK_FAC_STAKED_STARGATE_AM_WETH);
        (, exposure, riskFactor) = stakedStargateAM.riskParams(address(usdcLendingPool));
        assertEq(exposure, RiskParameters.EXPOSURE_STAKED_STARGATE_AM_USDC);
        assertEq(riskFactor, RiskParameters.RISK_FAC_STAKED_STARGATE_AM_USDC);

        (uint128 minUsdValueWeth, uint64 gracePeriodWeth, uint64 maxRecursiveCallsWeth) =
            registry.riskParams(address(wethLendingPool));
        assertEq(minUsdValueWeth, RiskParameters.MIN_USD_VALUE_WETH);
        assertEq(gracePeriodWeth, RiskParameters.GRACE_PERIOD_WETH);
        assertEq(maxRecursiveCallsWeth, RiskParameters.MAX_RECURSIVE_CALLS_WETH);

        (uint128 minUsdValueUsdc, uint64 gracePeriodUsdc, uint64 maxRecursiveCallsUsdc) =
            registry.riskParams(address(usdcLendingPool));
        assertEq(minUsdValueUsdc, RiskParameters.MIN_USD_VALUE_USDC);
        assertEq(gracePeriodUsdc, RiskParameters.GRACE_PERIOD_USDC);
        assertEq(maxRecursiveCallsUsdc, RiskParameters.MAX_RECURSIVE_CALLS_USDC);
    }
}
