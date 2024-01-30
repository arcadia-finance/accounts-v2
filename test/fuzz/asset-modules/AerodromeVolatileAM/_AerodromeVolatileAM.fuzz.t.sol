/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { AerodromeVolatileAMExtension } from "../../../utils/Extensions.sol";
import { AerodromeFactoryMock } from "../../../utils/mocks/Aerodrome/AerodromeFactoryMock.sol";
import { AerodromePoolMock } from "../../../utils/mocks/Aerodrome/AerodromePoolMock.sol";

/**
 * @notice Common logic needed by "AerodromeVolatileAM" fuzz tests.
 */
abstract contract AerodromeVolatileAM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AerodromeVolatileAMExtension internal aeroVolatileAM;
    AerodromeFactoryMock internal aeroFactoryMock;
    AerodromePoolMock internal aeroPoolMock;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy mocked AerodromeAM
        aeroFactoryMock = new AerodromeFactoryMock();
        aeroPoolMock = new AerodromePoolMock();

        // Deploy the Stargate AssetModule.
        vm.startPrank(users.creatorAddress);
        aeroVolatileAM = new AerodromeVolatileAMExtension(address(registryExtension), address(aeroFactoryMock));
        registryExtension.addAssetModule(address(aeroVolatileAM));
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function setInitialState() public {
        // Given : The asset is a pool in the the Aerodrome Factory.
        aeroFactoryMock.setPool(address(aeroPoolMock));

        // Given : The asset is an Aerodrome Volatile pool.
        aeroPoolMock.setStable(false);

        // Given : Token0 and token1 are added to the Registry
        aeroPoolMock.setTokens(address(mockERC20.token1), address(mockERC20.stable1));
    }
}
