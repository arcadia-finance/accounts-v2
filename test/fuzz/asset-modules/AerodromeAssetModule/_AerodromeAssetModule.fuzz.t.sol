/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { AerodromeAssetModule } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeAssetModule.sol";
import { AerodromeAssetModuleExtension } from "../../../utils/Extensions.sol";
import { AerodromePoolMock } from "../../../utils/mocks/Aerodrome/PoolMock.sol";
import { AerodromeGaugeMock } from "../../../utils/mocks/Aerodrome/GaugeMock.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";
import { ArcadiaOracle } from "../../../utils/mocks/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Common logic needed by "AbstractAssetModule" fuzz tests.
 */
abstract contract AerodromeAssetModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AerodromePoolMock internal pool;
    AerodromeGaugeMock internal gauge;
    AerodromeAssetModuleExtension internal aerodromeAssetModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);

        pool = new AerodromePoolMock();
        gauge = new AerodromeGaugeMock();
        gauge.setStakingToken(address(pool));
        aerodromeAssetModule = new AerodromeAssetModuleExtension(address(registryExtension));

        registryExtension.addAssetModule(address(aerodromeAssetModule));
        aerodromeAssetModule.initialize();

        ERC20Mock rewardTokenCode = new ERC20Mock("Aerodrome", "AERO", 18);

        vm.etch(address(aerodromeAssetModule.rewardToken()), address(rewardTokenCode).code);

        ArcadiaOracle aeroOracle = initMockedOracle(8, "AERO / USD", rates.token1ToUsd);

        vm.startPrank(registryExtension.owner());

        chainlinkOM.addOracle(address(aeroOracle), "AERO", "USD", 2 days);

        // Add AERO to the standardERC20AssetModule
        uint80[] memory oracleAeroToUsdArr = new uint80[](1);
        oracleAeroToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(aeroOracle)));

        erc20AssetModule.addAsset(
            address(aerodromeAssetModule.rewardToken()), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAeroToUsdArr)
        );

        vm.stopPrank();
    }
}
