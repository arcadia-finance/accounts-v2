/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { AerodromeStableAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeStableAM.sol";
import { AerodromeVolatileAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeVolatileAM.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { Pool } from "../../../utils/fixtures/aerodrome/AeroPoolFixture.f.sol";
import { PoolFactory } from "../../../utils/fixtures/aerodrome/AeroPoolFactoryFixture.f.sol";
import { WrappedAerodromeAMExtension } from "../../../utils/extensions/WrappedAerodromeAMExtension.sol";

/**
 * @notice Common logic needed by "WrappedAerodromeAM" fuzz tests.
 */
abstract contract WrappedAerodromeAM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AerodromeVolatileAM public aerodromeVolatileAM;
    AerodromeStableAM public aerodromeStableAM;
    Pool public pool;
    Pool public implementation;
    PoolFactory public poolFactory;
    WrappedAerodromeAMExtension public wrappedAerodromeAM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        // Deploy implementation of Aerodrome pool contract
        implementation = new Pool();

        // Deploy Aerodrome pool factory contract
        poolFactory = new PoolFactory(address(implementation));

        // Deploy Aerodrome Volatile and Stable pools.
        aerodromeVolatileAM = new AerodromeVolatileAM(address(registryExtension), address(poolFactory));
        registryExtension.addAssetModule(address(aerodromeVolatileAM));

        aerodromeStableAM = new AerodromeStableAM(address(registryExtension), address(poolFactory));
        registryExtension.addAssetModule(address(aerodromeStableAM));

        // Deploy WrappedAerodromeAM.
        wrappedAerodromeAM = new WrappedAerodromeAMExtension(address(registryExtension));
        registryExtension.addAssetModule(address(wrappedAerodromeAM));
        wrappedAerodromeAM.initialize();
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
}
