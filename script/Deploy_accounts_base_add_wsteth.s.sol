/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses, DeployNumbers, DeployRiskConstantsBase } from "./Constants/DeployConstants.sol";

import { BitPackingLib } from "../src/libraries/BitPackingLib.sol";

import { Registry } from "../src/Registry.sol";
import { ChainlinkOM } from "../src/oracle-modules/ChainlinkOM.sol";
import { ERC20PrimaryAM } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";

import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { ERC20 } from "../lib/solmate/src/tokens/ERC20.sol";

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

        wsteth = ERC20(DeployAddresses.wsteth_base);
        BA_TO_QA_DOUBLE[0] = true;
        BA_TO_QA_DOUBLE[1] = true;
    }

    function run() public {
        wethLendingPool = ILendingPool(0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2);
        usdcLendingPool = ILendingPool(0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1);
        registry = Registry(0xd0690557600eb8Be8391D1d97346e2aab5300d5f);
        chainlinkOM = ChainlinkOM(0x6a5485E3ce6913890ae5e8bDc08a868D432eEB31);
        erc20PrimaryAM = ERC20PrimaryAM(0xfBecEaFC96ed6fc800753d3eE6782b6F9a60Eed7);

        vm.startBroadcast(DeployAddresses.protocolOwner_base);
        oracleWstethToEthId = uint80(
            chainlinkOM.addOracle(
                DeployAddresses.oracleWstethToEth_base, "wstETH", "ETH", DeployNumbers.wsteth_eth_cutOffTime
            )
        );

        oracleWstethToEthToUsdArr[0] = oracleWstethToEthId;
        oracleWstethToEthToUsdArr[1] = DeployNumbers.EthToUsdOracleId;

        erc20PrimaryAM.addAsset(
            DeployAddresses.wsteth_base, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleWstethToEthToUsdArr)
        );
        vm.stopBroadcast();

        vm.startBroadcast(DeployAddresses.riskManager_base);
        registry.setRiskParametersOfPrimaryAsset(
            address(wethLendingPool),
            DeployAddresses.wsteth_base,
            0,
            DeployRiskConstantsBase.wsteth_exposure_eth,
            DeployRiskConstantsBase.wsteth_collFact_eth,
            DeployRiskConstantsBase.wsteth_liqFact_eth
        );

        registry.setRiskParametersOfPrimaryAsset(
            address(usdcLendingPool),
            DeployAddresses.wsteth_base,
            0,
            DeployRiskConstantsBase.wsteth_exposure_usdc,
            DeployRiskConstantsBase.wsteth_collFact_usdc,
            DeployRiskConstantsBase.wsteth_liqFact_usdc
        );

        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
