/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StakedAerodromeAM_Fuzz_Test, StakedAerodromeAM } from "./_StakedAerodromeAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

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

    function testFuzz_Revert_constructor_RewardTokenNotAllowed() public {
        // Given: No asset module is set for the rewardToken
        registryExtension.setAssetModule(AERO, address(0));

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.expectRevert(StakedAerodromeAM.RewardTokenNotAllowed.selector);
        new StakedAerodromeAM(address(registryExtension), address(voter));
    }

    function testFuzz_success_constructor() public {
        StakedAerodromeAM assetModule = new StakedAerodromeAM(address(registryExtension), address(voter));

        assertEq(address(assetModule.REWARD_TOKEN()), AERO);
        assertEq(assetModule.ASSET_TYPE(), 2);
        assertEq(assetModule.REGISTRY(), address(registryExtension));
        assertEq(assetModule.symbol(), "aSAEROP");
        assertEq(assetModule.name(), "Arcadia Staked Aerodrome Positions");
        assertEq(address(assetModule.AERO_VOTER()), address(voter));
    }
}
