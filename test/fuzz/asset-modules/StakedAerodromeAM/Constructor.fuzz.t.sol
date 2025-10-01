/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { StakedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";
import { StakedAerodromeAM_Fuzz_Test } from "./_StakedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the constructor of contract "StakedAerodromeAM".
 */
contract Constructor_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/
    function testFuzz_success_constructor() public {
        StakedAerodromeAM assetModule = new StakedAerodromeAM(users.owner, address(registry), address(voter), AERO);

        assertEq(address(assetModule.REWARD_TOKEN()), AERO);
        assertEq(assetModule.ASSET_TYPE(), 2);
        assertEq(assetModule.REGISTRY(), address(registry));
        assertEq(assetModule.symbol(), "aSAEROP");
        assertEq(assetModule.name(), "Arcadia Staked Aerodrome Positions");
        assertEq(address(assetModule.AERO_VOTER()), address(voter));
    }
}
