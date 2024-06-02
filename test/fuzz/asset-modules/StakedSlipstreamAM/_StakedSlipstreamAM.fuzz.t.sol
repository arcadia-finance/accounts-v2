/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";
import { SlipstreamFixture } from "../../../utils/fixtures/slipstream/Slipstream.f.sol";

import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { FactoryRegistryMock } from "../../../utils/mocks/Aerodrome/FactoryRegistryMock.sol";
import { VoterMock } from "../../../utils/mocks/Aerodrome/VoterMock.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Common logic needed by all "StakedSlipstreamAM" fuzz tests.
 */
abstract contract StakedSlipstreamAM_Fuzz_Test is Fuzz_Test, SlipstreamFixture {
    using stdStorage for StdStorage;
    /*////////////////////////////////////////////////////////////////
                            CONSTANTS
    /////////////////////////////////////////////////////////////// */

    address AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;

    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    ArcadiaOracle internal aeroOracle;
    VoterMock internal voter;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, SlipstreamFixture) {
        Fuzz_Test.setUp();
        SlipstreamFixture.setUp();

        // Deploy Aerodrome Mocks.
        FactoryRegistryMock factoryRegistry = new FactoryRegistryMock();
        voter = new VoterMock(address(factoryRegistry));

        // Deploy fixture for Slipstream.
        deploySlipstream(address(voter));

        // Deploy fixture for CLGaugeFactory.
        deployCLGaugeFactory(address(voter));
        factoryRegistry.setFactoriesToPoolFactory(address(cLFactory), address(0), address(cLGaugeFactory));

        // Deploy AERO reward token.
        deployAero();
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function deployAero() internal {
        // Mock Aero
        ERC20Mock rewardToken = new ERC20Mock("Aerodrome", "AERO", 18);
        vm.etch(AERO, address(rewardToken).code);
        aeroOracle = initMockedOracle(8, "AERO / USD", rates.token1ToUsd);

        // Add AERO to the ERC20PrimaryAM.
        vm.startPrank(users.creatorAddress);
        chainlinkOM.addOracle(address(aeroOracle), "AERO", "USD", 2 days);
        uint80[] memory oracleAeroToUsdArr = new uint80[](1);
        oracleAeroToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(aeroOracle)));
        erc20AssetModule.addAsset(AERO, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAeroToUsdArr));
        vm.stopPrank();
    }
}
