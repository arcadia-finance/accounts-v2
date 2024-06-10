/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StakedAerodromeAM_Fuzz_Test, StakedAerodromeAM } from "./_StakedAerodromeAM.fuzz.t.sol";
import { Pool } from "../../../utils/mocks/Aerodrome/AeroPoolMock.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

/**
 * @notice Fuzz tests for the "addAsset" function of contract "StakedAerodromeAM".
 */
contract AddAsset_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_AddAsset_GaugeNotValid(address gauge_) public {
        // When : Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM.GaugeNotValid.selector);
        stakedAerodromeAM.addAsset(gauge_);
    }

    function testFuzz_Revert_AddAsset_PoolNotAllowed(bool stable) public {
        // And : Valid aeroPool
        aeroPool = createPoolAerodrome(address(mockERC20.stable1), address(mockERC20.token1), stable);

        // And : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, address(stakedAerodromeAM.REWARD_TOKEN()));

        // When :  Calling addAsset()
        // Then : It should revert as the aeroPool has not been added to the registry
        vm.expectRevert(StakedAerodromeAM.PoolNotAllowed.selector);
        stakedAerodromeAM.addAsset(address(aeroGauge));
    }

    function testFuzz_Revert_AddAsset_AssetAlreadySet() public {
        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // And : Gauge exists
        aeroGauge = createGaugeAerodrome(aeroPool, address(stakedAerodromeAM.REWARD_TOKEN()));

        // Given : aeroPool is already added to the AM
        stakedAerodromeAM.setAllowed(address(aeroPool), true);

        // When :  Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM.AssetAlreadySet.selector);
        stakedAerodromeAM.addAsset(address(aeroGauge));
    }

    function testFuzz_Revert_AddAsset_RewardTokenNotValid(address notAERO) public {
        vm.assume(notAERO != AERO);
        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // Given : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, notAERO);

        // When :  Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM.RewardTokenNotValid.selector);
        stakedAerodromeAM.addAsset(address(aeroGauge));
    }

    function testFuzz_Success_AddAsset() public {
        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // Given : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);

        // When : Calling addAsset()
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // Then : Asset and aeroGauge info should be updated
        assertEq(stakedAerodromeAM.assetToGauge(address(aeroPool)), address(aeroGauge));
        (,, bool allowed) = stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(allowed, true);
    }
}
