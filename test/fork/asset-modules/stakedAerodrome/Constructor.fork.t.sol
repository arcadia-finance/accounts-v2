/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StakedAerodromeAM_Fork_Test, StakedAerodromeAM } from "./_StakedAerodromeAM.fork.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Fork tests for the constructor of contract "StakedAerodromeAM".
 */
contract Constructor_StakedAerodromeAM_Fork_Test is StakedAerodromeAM_Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_Fork_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFork_Revert_constructor_RewardTokenNotAllowed() public {
        // Given: No asset module is set for the rewardToken
        registryExtension.setAssetToAssetModule(AERO, address(0));

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.prank(users.creatorAddress);
        vm.expectRevert(StakedAerodromeAM.RewardTokenNotAllowed.selector);
        new StakedAerodromeAM(address(registryExtension));
    }

    function testFork_success_constructor() public {
        StakedAerodromeAM assetModule = new StakedAerodromeAM(address(registryExtension));

        assertEq(address(assetModule.REWARD_TOKEN()), AERO);
        assertEq(assetModule.ASSET_TYPE(), 1);
        assertEq(assetModule.REGISTRY(), address(registryExtension));
        assertEq(assetModule.symbol(), "aAEROP");
        assertEq(assetModule.name(), "Arcadia Aerodrome Positions");
    }
}
