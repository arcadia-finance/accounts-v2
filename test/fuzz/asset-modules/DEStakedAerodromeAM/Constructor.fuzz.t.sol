/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { DEStakedAerodromeAM_Fuzz_Test, DEStakedAerodromeAM } from "./_DEStakedAerodromeAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

/**
 * @notice Fuzz tests for the constructor of contract "DEStakedAerodromeAM".
 */
contract Constructor_DEStakedAerodromeAM_Fuzz_Test is DEStakedAerodromeAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        DEStakedAerodromeAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_constructor_RewardTokenNotAllowed() public {
        // Given: No asset module is set for the rewardToken
        registryExtension.setAssetModule(AERO, address(0));

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.expectRevert(DEStakedAerodromeAM.RewardTokenNotAllowed.selector);
        new DEStakedAerodromeAM(address(registryExtension), address(voter));
    }

    function testFuzz_success_constructor() public {
        DEStakedAerodromeAM assetModule = new DEStakedAerodromeAM(address(registryExtension), address(voter));

        assertEq(address(assetModule.REWARD_TOKEN()), AERO);
        assertEq(assetModule.ASSET_TYPE(), 2);
        assertEq(assetModule.REGISTRY(), address(registryExtension));
        assertEq(assetModule.symbol(), "aAEROPDE");
        assertEq(assetModule.name(), "Arcadia Aerodrome Positions DE");
        assertEq(address(assetModule.AERO_VOTER()), address(voter));
    }
}
