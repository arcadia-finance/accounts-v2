/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { StakedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";
import { StakedAerodromeAM_Fuzz_Test } from "./_StakedAerodromeAM.fuzz.t.sol";
import { StakingAM } from "../../../../src/asset-modules/abstracts/AbstractStakingAM.sol";

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

    function testFuzz_Revert_constructor_RecipientNotValid(
        address owner_,
        address registry_,
        address aerodromeVoter,
        address rewardToken_
    ) public {
        // Given: The recipient is the zero address.
        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(StakingAM.RecipientNotValid.selector);
        new StakedAerodromeAM(owner_, registry_, aerodromeVoter, rewardToken_, address(0));
    }

    function testFuzz_Success_constructor(
        address owner_,
        address registry_,
        address aerodromeVoter,
        address rewardToken_,
        address surplusRecipient_
    ) public {
        // Given: The recipient is not the zero address.
        vm.assume(surplusRecipient_ != address(0));

        // When: The Asset Module is deployed.
        StakedAerodromeAM assetModule =
            new StakedAerodromeAM(owner_, registry_, aerodromeVoter, rewardToken_, surplusRecipient_);

        // Then: The immutables and the metadata are set.
        assertEq(address(assetModule.REWARD_TOKEN()), rewardToken_);
        assertEq(assetModule.ASSET_TYPE(), 2);
        assertEq(assetModule.owner(), owner_);
        assertEq(assetModule.REGISTRY(), registry_);
        assertEq(assetModule.symbol(), "aSAEROP");
        assertEq(assetModule.name(), "Arcadia Staked Aerodrome Positions");
        assertEq(address(assetModule.AERO_VOTER()), aerodromeVoter);
        assertEq(assetModule.surplusRecipient(), surplusRecipient_);
    }
}
