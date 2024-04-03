/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import {
    StakedAerodromeAM_DirectEmissions_Fuzz_Test,
    StakedAerodromeAM_DirectEmissions
} from "./_StakedAerodromeAM_DirectEmissions.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

/**
 * @notice Fuzz tests for the "addAsset" function of contract "StakedAerodromeAM_DirectEmissions".
 */
contract AddAsset_StakedAerodromeAM_DirectEmissions_Fuzz_Test is StakedAerodromeAM_DirectEmissions_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_DirectEmissions_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_AddAsset_PoolNotAllowed(address pool_, address gauge_) public notTestContracts(pool_) {
        // When :  Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM_DirectEmissions.PoolNotAllowed.selector);
        stakedAerodromeAM.addAsset(pool_, gauge_);
    }

    function testFuzz_Revert_AddAsset_AssetAlreadySet(address gauge_) public {
        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // Given : pool is already added to the AM
        stakedAerodromeAM.setAllowed(address(pool), true);

        // When :  Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM_DirectEmissions.AssetAlreadySet.selector);
        stakedAerodromeAM.addAsset(address(pool), gauge_);
    }

    function testFuzz_Revert_AddAsset_GaugeNotValid(address gauge_) public {
        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // When : Calling addAsset
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM_DirectEmissions.GaugeNotValid.selector);
        stakedAerodromeAM.addAsset(address(pool), gauge_);
    }

    function testFuzz_Revert_AddAsset_PoolOrGaugeNotValid(address notPool) public {
        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // Given : Valid gauge
        deployAerodromeGaugeFixture(notPool, address(stakedAerodromeAM.REWARD_TOKEN()));

        // Given :
        // When :  Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM_DirectEmissions.PoolOrGaugeNotValid.selector);
        stakedAerodromeAM.addAsset(address(pool), address(gauge));
    }

    function testFuzz_Revert_AddAsset_RewardTokenNotValid(address notAERO) public {
        vm.assume(notAERO != AERO);
        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // Given : Valid gauge
        deployAerodromeGaugeFixture(address(pool), notAERO);

        // When :  Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM_DirectEmissions.RewardTokenNotValid.selector);
        stakedAerodromeAM.addAsset(address(pool), address(gauge));
    }

    function testFuzz_Success_AddAsset() public {
        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // Given : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);

        // When : Calling addAsset()
        stakedAerodromeAM.addAsset(address(pool), address(gauge));

        // Then : Asset and gauge info should be updated
        assertEq(stakedAerodromeAM.assetToGauge(address(pool)), address(gauge));
        (,, bool allowed) = stakedAerodromeAM.assetState(address(pool));
        assertEq(allowed, true);
    }
}
