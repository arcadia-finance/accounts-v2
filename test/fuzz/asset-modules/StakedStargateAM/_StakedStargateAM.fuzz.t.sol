/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAM_Fuzz_Test } from "../StargateAM/_StargateAM.fuzz.t.sol";

import { StakedStargateAMExtension } from "../../../utils/Extensions.sol";
import { LPStakingTimeMock } from "../../../utils/mocks/Stargate/StargateLpStakingMock.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Common logic needed by "StakedStargateAM" fuzz tests.
 */
abstract contract StakedStargateAM_Fuzz_Test is StargateAM_Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    StakedStargateAMExtension internal stakedStargateAM;
    LPStakingTimeMock internal lpStakingTimeMock;
    ArcadiaOracle internal stargateOracle;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(StargateAM_Fuzz_Test) {
        StargateAM_Fuzz_Test.setUp();

        // Deploy mocked Stargate Staking contract.
        lpStakingTimeMock = new LPStakingTimeMock();

        // Deploy reward token.
        ERC20Mock rewardTokenCode = new ERC20Mock("Stargate", "STG", 18);
        vm.etch(address(lpStakingTimeMock.eToken()), address(rewardTokenCode).code);
        stargateOracle = initMockedOracle(8, "STG / USD", rates.token1ToUsd);

        // Add STG to the ERC20PrimaryAM.
        vm.startPrank(users.creatorAddress);
        chainlinkOM.addOracle(address(stargateOracle), "STG", "USD", 2 days);
        uint80[] memory oracleStgToUsdArr = new uint80[](1);
        oracleStgToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(stargateOracle)));
        erc20AssetModule.addAsset(
            address(lpStakingTimeMock.eToken()), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStgToUsdArr)
        );

        // Deploy the Staked Stargate AssetModule.
        stakedStargateAM = new StakedStargateAMExtension(address(registryExtension), address(lpStakingTimeMock));
        registryExtension.addAssetModule(address(stakedStargateAM));
        stakedStargateAM.initialize();
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
}
