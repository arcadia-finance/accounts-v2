/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Test } from "../lib/forge-std/src/Test.sol";

import { ArcadiaSafes, CutOffTimes, OracleIds, Oracles, PrimaryAssets, RiskParameters } from "./utils/ConstantsBase.sol";
import { BitPackingLib } from "../src/libraries/BitPackingLib.sol";
import { ChainlinkOM } from "../src/oracle-modules/ChainlinkOM.sol";
import { ERC20 } from "../lib/solmate/src/tokens/ERC20.sol";
import { ERC20PrimaryAM } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { Registry } from "../src/Registry.sol";

contract ArcadiaAccountDeploymentAddWsteth is Test {
    ERC20 internal wsteth;

    Registry internal registry;

    ERC20PrimaryAM internal erc20PrimaryAM;

    ChainlinkOM internal chainlinkOM;

    ILendingPool internal wethLendingPool;
    ILendingPool internal usdcLendingPool;

    bool[] internal BA_TO_QA_DOUBLE = new bool[](2);
    uint80[] internal oracleWstethToEthToUsdArr = new uint80[](2);
    uint80 internal oracleWstethToEthId;

    constructor() {
        // /*///////////////////////////////////////////////////////////////
        //                   ADDRESSES
        // ///////////////////////////////////////////////////////////////*/

        wsteth = ERC20(PrimaryAssets.WSTETH);
        BA_TO_QA_DOUBLE[0] = true;
        BA_TO_QA_DOUBLE[1] = true;
    }

    function run() public {
        wethLendingPool = ILendingPool(0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2);
        usdcLendingPool = ILendingPool(0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1);
        registry = Registry(0xd0690557600eb8Be8391D1d97346e2aab5300d5f);
        chainlinkOM = ChainlinkOM(0x6a5485E3ce6913890ae5e8bDc08a868D432eEB31);
        erc20PrimaryAM = ERC20PrimaryAM(0xfBecEaFC96ed6fc800753d3eE6782b6F9a60Eed7);

        vm.startBroadcast(ArcadiaSafes.OWNER);
        oracleWstethToEthId = uint80(chainlinkOM.addOracle(Oracles.WSTETH_ETH, "wstETH", "ETH", CutOffTimes.WSTETH_ETH));

        oracleWstethToEthToUsdArr[0] = oracleWstethToEthId;
        oracleWstethToEthToUsdArr[1] = OracleIds.ETH_USD;

        erc20PrimaryAM.addAsset(PrimaryAssets.WSTETH, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleWstethToEthToUsdArr));
        vm.stopBroadcast();

        vm.startBroadcast(ArcadiaSafes.RISK_MANAGER);
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            PrimaryAssets.WSTETH,
            0,
            RiskParameters.EXPOSURE_WSTETH_WETH,
            RiskParameters.COL_FAC_WSTETH_WETH,
            RiskParameters.LIQ_FAC_WSTETH_WETH
        );

        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            PrimaryAssets.WSTETH,
            0,
            RiskParameters.EXPOSURE_WSTETH_USDC,
            RiskParameters.COL_FAC_WSTETH_USDC,
            RiskParameters.LIQ_FAC_WSTETH_USDC
        );

        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
