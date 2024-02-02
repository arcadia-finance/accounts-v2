/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StakedAerodromeAM_Fork_Test, StakedAerodromeAM } from "./_StakedAerodromeAM.fork.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { stdStorage, StdStorage } from "../../../../lib/forge-std/src/StdStorage.sol";
import { AerodromeGaugeMock } from "../../../utils/mocks/Aerodrome/AerodromeGaugeMock.sol";

/**
 * @notice Fork tests for the "addAsset" function of contract "StakedAerodromeAM".
 */
contract AddAsset_StakedAerodromeAM_Fork_Test is StakedAerodromeAM_Fork_Test {
    using stdStorage for StdStorage;
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_Fork_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFork_Revert_AddAsset_PoolNotAllowed() public {
        // Given : asset is not in the AerodromeStableAssetModule.
        stdstore.target(address(aerodromeStableAM)).sig(aerodromeStableAM.inAssetModule.selector).with_key(stablePool)
            .checked_write(false);

        // When :  Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM.PoolNotAllowed.selector);
        stakedAerodromeAM.addAsset(stablePool, stableGauge);
    }

    function testFork_Revert_AddAsset_AssetAlreadySet() public {
        // Given : stablePool is already added to the AM
        stakedAerodromeAM.setAllowed(stablePool, true);

        // When :  Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM.AssetAlreadySet.selector);
        stakedAerodromeAM.addAsset(stablePool, stableGauge);
    }

    function testFork_Revert_AddAsset_GaugeNotValid() public {
        // Given : 0x02 is not a valid gauge
        // When :  Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM.GaugeNotValid.selector);
        stakedAerodromeAM.addAsset(stablePool, address(0x02));
    }

    function testFork_Revert_AddAsset_PoolOrGaugeNotValid() public {
        // When :  Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM.PoolOrGaugeNotValid.selector);
        stakedAerodromeAM.addAsset(stablePool, volatileGauge);
    }

    function testFork_Revert_AddAsset_RewardTokenNotValid() public {
        // Note : to adapt
        /*         AerodromeGaugeMock gauge = new AerodromeGaugeMock();
        
        // Given : rewardToken is not valid in gauge (!= AERO)
        gauge.setRewardToken(address(USDC));
        // Given : stakingToken is valid in gauge
        gauge.setStakingToken(stablePool);
        
        // When :  Calling addAsset()
        // Then : It should revert
        vm.expectRevert(StakedAerodromeAM.RewardTokenNotValid.selector);
        stakedAerodromeAM.addAsset(stablePool, address(gauge)); */
    }

    function testFork_Success_AddAsset() public {
        // When :  Calling addAsset()
        stakedAerodromeAM.addAsset(stablePool, stableGauge);

        // Then : Asset and gauge info should be updated
        assertEq(stakedAerodromeAM.assetToGauge(stablePool), stableGauge);
        (bool allowed,,,) = stakedAerodromeAM.assetState(stablePool);
        assertEq(allowed, true);
    }
}
