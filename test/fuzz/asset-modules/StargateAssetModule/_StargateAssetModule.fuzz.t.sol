/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { StargateAssetModule } from "../../../../src/asset-modules/Stargate-Finance/StargateAssetModule.sol";
import { StargateAssetModuleExtension } from "../../../utils/Extensions.sol";
import { LPStakingTimeMock } from "../../../utils/mocks/Stargate/StargateLpStakingMock.sol";
import { StargatePoolMock } from "../../../utils/mocks/Stargate/StargatePoolMock.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";
import { ArcadiaOracle } from "../../../utils/mocks/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Common logic needed by "StargateAssetModule" fuzz tests.
 */
abstract contract StargateAssetModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    StargatePoolMock internal poolMock;
    StargateAssetModuleExtension internal stargateAssetModule;
    LPStakingTimeMock internal lpStakingTimeMock;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy mocked Stargate.
        poolMock = new StargatePoolMock(18);
        lpStakingTimeMock = new LPStakingTimeMock();
        ERC20Mock rewardTokenCode = new ERC20Mock("Stargate", "STG", 18);
        vm.etch(address(lpStakingTimeMock.eToken()), address(rewardTokenCode).code);
        ArcadiaOracle stargateOracle = initMockedOracle(8, "STG / USD", rates.token1ToUsd);

        // Add STG to the standardERC20AssetModule.
        vm.startPrank(users.creatorAddress);
        chainlinkOM.addOracle(address(stargateOracle), "STG", "USD", 2 days);
        uint80[] memory oracleStgToUsdArr = new uint80[](1);
        oracleStgToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(stargateOracle)));
        erc20AssetModule.addAsset(
            address(lpStakingTimeMock.eToken()), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStgToUsdArr)
        );

        // Deploy the Stargate AssetModule.
        stargateAssetModule = new StargateAssetModuleExtension(address(registryExtension), address(lpStakingTimeMock));
        registryExtension.addAssetModule(address(stargateAssetModule));
        stargateAssetModule.initialize();
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
}
