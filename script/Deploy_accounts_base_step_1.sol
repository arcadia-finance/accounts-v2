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

contract ArcadiaAccountDeploymentStep1 is Test {
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
    uint80[] internal oracleCbethToUsdArr = new uint80[](1);
    uint80[] internal oracleRethToEthToUsdArr = new uint80[](2);
    uint80[] internal oracleStgToUsdArr = new uint80[](1);

    uint80 internal oracleCompToUsdId;
    uint80 internal oracleDaiToUsdId;
    uint80 internal oracleEthToUsdId;
    uint80 internal oracleUsdcToUsdId;
    uint80 internal oracleUsdbcToUsdId;
    uint80 internal oracleCbethToUsdId;
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
        address protocolOwnerAddress = DeployAddresses.protocolOwner_base;

        assertEq(deployerAddress, protocolOwnerAddress);

        vm.startBroadcast(deployerPrivateKey);
        factory = Factory(0xDa14Fdd72345c4d2511357214c5B89A919768e59); //todo: change after factory deploy
        wethLendingPool = ILendingPool(0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2); //todo: change after LP deploy
        usdcLendingPool = ILendingPool(0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1); //todo: change after LP deploy
        wethLendingPool.setRiskManager(protocolOwnerAddress);
        usdcLendingPool.setRiskManager(protocolOwnerAddress);

        registry = new Registry(address(factory), DeployAddresses.sequencerUptimeOracle_base);

        chainlinkOM = new ChainlinkOM(address(registry));

        account = new AccountV1(address(factory));
        actionMultiCall = new ActionMultiCall();

        erc20PrimaryAM = new ERC20PrimaryAM(address(registry));

        registry.addAssetModule(address(erc20PrimaryAM));

        registry.addOracleModule(address(chainlinkOM));

        oracleCompToUsdId = uint80(
            chainlinkOM.addOracle(
                DeployAddresses.oracleCompToUsd_base, "COMP", "USD", DeployNumbers.comp_usd_cutOffTime
            )
        );
        oracleDaiToUsdId = uint80(
            chainlinkOM.addOracle(DeployAddresses.oracleDaiToUsd_base, "DAI", "USD", DeployNumbers.dai_usd_cutOffTime)
        );
        oracleEthToUsdId = uint80(
            chainlinkOM.addOracle(DeployAddresses.oracleEthToUsd_base, "ETH", "USD", DeployNumbers.eth_usd_cutOffTime)
        );
        oracleUsdcToUsdId = uint80(
            chainlinkOM.addOracle(
                DeployAddresses.oracleUsdcToUsd_base, "USDC", "USD", DeployNumbers.usdc_usd_cutOffTime
            )
        );
        oracleCbethToUsdId = uint80(
            chainlinkOM.addOracle(
                DeployAddresses.oracleCbethToUsd_base, "CBETH", "USD", DeployNumbers.cbeth_usd_cutOffTime
            )
        );
        oracleRethToEthId = uint80(
            chainlinkOM.addOracle(
                DeployAddresses.oracleRethToEth_base, "RETH", "ETH", DeployNumbers.reth_eth_cutOffTime
            )
        );
        oracleStgToUsdId = uint80(
            chainlinkOM.addOracle(DeployAddresses.oracleStgToUsd_base, "STG", "USD", DeployNumbers.stg_usd_cutOffTime)
        );

        oracleCompToUsdArr[0] = oracleCompToUsdId;
        oracleDaiToUsdArr[0] = oracleDaiToUsdId;
        oracleEthToUsdArr[0] = oracleEthToUsdId;
        oracleUsdcToUsdArr[0] = oracleUsdcToUsdId;
        oracleUsdbcToUsdArr[0] = oracleUsdcToUsdId;
        oracleCbethToUsdArr[0] = oracleCbethToUsdId;
        oracleRethToEthToUsdArr[0] = oracleRethToEthId;
        oracleRethToEthToUsdArr[1] = oracleEthToUsdId;
        oracleStgToUsdArr[0] = oracleStgToUsdId;

        erc20PrimaryAM.addAsset(DeployAddresses.comp_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleCompToUsdArr));
        erc20PrimaryAM.addAsset(DeployAddresses.dai_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleDaiToUsdArr));
        erc20PrimaryAM.addAsset(DeployAddresses.weth_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleEthToUsdArr));
        erc20PrimaryAM.addAsset(DeployAddresses.usdc_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleUsdcToUsdArr));
        erc20PrimaryAM.addAsset(DeployAddresses.usdbc_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleUsdbcToUsdArr));
        erc20PrimaryAM.addAsset(DeployAddresses.cbeth_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleCbethToUsdArr));
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
        stakedStargateAM.addAsset(DeployNumbers.stargateUsdbcPid);

        factory.setNewAccountInfo(address(registry), address(account), DeployBytes.upgradeRoot1To1, "");
        factory.changeGuardian(protocolOwnerAddress);

        registry.changeGuardian(protocolOwnerAddress);

        wethLendingPool.setAccountVersion(1, true);
        usdcLendingPool.setAccountVersion(1, true);

        vm.stopBroadcast();

        test_deploy();
    }

    function test_deploy() public {
        vm.skip(true);

        address protocolOwnerAddress = DeployAddresses.protocolOwner_base;

        assertEq(factory.owner(), protocolOwnerAddress);
        assertEq(factory.guardian(), protocolOwnerAddress);

        assertEq(registry.owner(), protocolOwnerAddress);
        assertEq(registry.guardian(), protocolOwnerAddress);

        assertEq(account.owner(), protocolOwnerAddress);
        assertEq(account.registry(), address(registry));
        assertEq(account.liquidator(), address(0));
        assertEq(account.minimumMargin(), 0);
        assertEq(account.numeraire(), address(0));
        assertEq(account.creditor(), address(0));

        assertEq(wethLendingPool.isValidVersion(account.ACCOUNT_VERSION()), true);
        assertEq(usdcLendingPool.isValidVersion(account.ACCOUNT_VERSION()), true);
        assertEq(wethLendingPool.riskManager(), protocolOwnerAddress);
        assertEq(usdcLendingPool.riskManager(), protocolOwnerAddress);

        assertTrue(registry.inRegistry(address(comp)));
        assertTrue(registry.inRegistry(address(dai)));
        assertTrue(registry.inRegistry(address(weth)));
        assertTrue(registry.inRegistry(address(usdc)));
        assertTrue(registry.inRegistry(address(usdbc)));
        assertTrue(registry.inRegistry(address(cbeth)));
        assertTrue(registry.inRegistry(address(reth)));
        assertTrue(registry.inRegistry(address(stg)));

        assertTrue(erc20PrimaryAM.inAssetModule(address(comp)));
        assertTrue(erc20PrimaryAM.inAssetModule(address(dai)));
        assertTrue(erc20PrimaryAM.inAssetModule(address(weth)));
        assertTrue(erc20PrimaryAM.inAssetModule(address(usdc)));
        assertTrue(erc20PrimaryAM.inAssetModule(address(usdbc)));
        assertTrue(erc20PrimaryAM.inAssetModule(address(cbeth)));
        assertTrue(erc20PrimaryAM.inAssetModule(address(reth)));
        assertTrue(erc20PrimaryAM.inAssetModule(address(stg)));

        assertTrue(uniswapV3AM.inAssetModule(DeployAddresses.uniswapV3PositionMgr_base));
    }
}
