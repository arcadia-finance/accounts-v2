/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeAssetModule_Fuzz_Test } from "./_AerodromeAssetModule.fuzz.t.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";

/**
 * @notice Fuzz tests for the function "_stake" of contract "AerodromeAssetModule".
 */
contract Stake_AerodromeAssetModule_Fuzz_Test is AerodromeAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_success_stake(uint256 amount) public {
        // Given : Asset and gauge are set in AM
        aerodromeAssetModule.setAssetToGauge(address(pool), address(gauge));

        // And : Assets are previously transfered in the AM
        deal(address(pool), address(aerodromeAssetModule), amount);

        // When : Calling stake()
        aerodromeAssetModule.stakeExtension(address(pool), amount);

        // Then : Asset should be transfered to gauge
        assertEq(pool.balanceOf(address(gauge)), amount);
    }
}
