/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { StakedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";
import { StakedAerodromeAM_Fuzz_Test } from "./_StakedAerodromeAM.fuzz.t.sol";

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
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_addAsset_GaugeNotValid(address gauge_) public {
        // Given: An address the Aerodrome Voter does not know as a gauge.

        // When: Calling addAsset().
        // Then: It reverts.
        vm.expectRevert(StakedAerodromeAM.GaugeNotValid.selector);
        stakedAerodromeAM.addAsset(gauge_);
    }

    function testFuzz_Revert_addAsset_PoolNotAllowed(bool stable) public {
        // Given: A valid aeroPool, which was never allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.stable1), address(mockERC20.token1), stable);

        // And: A valid aeroGauge.
        aeroGauge = createGaugeAerodrome(aeroPool, address(stakedAerodromeAM.REWARD_TOKEN()));

        // When: Calling addAsset().
        // Then: It reverts.
        vm.expectRevert(StakedAerodromeAM.PoolNotAllowed.selector);
        stakedAerodromeAM.addAsset(address(aeroGauge));
    }

    function testFuzz_Revert_addAsset_AssetAlreadySet(bool stable) public {
        // Given: The aeroPool is allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), stable);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // And: A valid aeroGauge.
        aeroGauge = createGaugeAerodrome(aeroPool, address(stakedAerodromeAM.REWARD_TOKEN()));

        // And: The aeroPool is already added to the Asset Module.
        stakedAerodromeAM.setAllowed(address(aeroPool), true);

        // When: Calling addAsset().
        // Then: It reverts.
        vm.expectRevert(StakedAerodromeAM.AssetAlreadySet.selector);
        stakedAerodromeAM.addAsset(address(aeroGauge));
    }

    function testFuzz_Revert_addAsset_RewardTokenNotValid(bool stable, address notAero) public {
        // Given: The aeroPool is allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), stable);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // And: An aeroGauge that pays out another token than the Reward Token of the Asset Module.
        vm.assume(notAero != AERO);
        aeroGauge = createGaugeAerodrome(aeroPool, notAero);

        // When: Calling addAsset().
        // Then: It reverts.
        vm.expectRevert(StakedAerodromeAM.RewardTokenNotValid.selector);
        stakedAerodromeAM.addAsset(address(aeroGauge));
    }

    function testFuzz_Revert_addAsset_RewardTokenNotAllowed(bool stable) public {
        // Given: The aeroPool is allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), stable);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // And: A valid aeroGauge.
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);

        // And: No Asset Module is set for the Reward Token.
        registry.setAssetModule(AERO, address(0));

        // When: Calling addAsset().
        // Then: It reverts.
        vm.expectRevert(StakedAerodromeAM.RewardTokenNotAllowed.selector);
        stakedAerodromeAM.addAsset(address(aeroGauge));
    }

    function testFuzz_Success_addAsset(bool stable) public {
        // Given: The aeroPool is allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), stable);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // And: A valid aeroGauge.
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);

        // When: Calling addAsset().
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // Then: Asset and aeroGauge info should be updated.
        assertEq(stakedAerodromeAM.assetToGauge(address(aeroPool)), address(aeroGauge));
        (,, bool allowed) = stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(allowed, true);

        // And: Asset module is initiated.
        assertTrue(stakedAerodromeAM.isInitialized());
    }
}
