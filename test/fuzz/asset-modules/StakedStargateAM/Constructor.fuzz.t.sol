/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedStargateAM } from "../../../../src/asset-modules/Stargate-Finance/StakedStargateAM.sol";
import { StakedStargateAM_Fuzz_Test } from "./_StakedStargateAM.fuzz.t.sol";
import { StakingAM } from "../../../../src/asset-modules/abstracts/AbstractStakingAM.sol";

/**
 * @notice Fuzz tests for the constructor of contract "StakedStargateAM".
 */
contract Constructor_StakedStargateAM_Fuzz_Test is StakedStargateAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedStargateAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_constructor_RecipientNotValid() public {
        // Given: The recipient is the zero address.
        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(StakingAM.RecipientNotValid.selector);
        new StakedStargateAM(users.owner, address(registry), address(lpStakingTimeMock), address(0));
    }

    function testFuzz_success_constructor(address surplusRecipient_) public {
        // Given: The recipient is not the zero address.
        vm.assume(surplusRecipient_ != address(0));

        // When: The Asset Module is deployed.
        StakedStargateAM assetModule =
            new StakedStargateAM(users.owner, address(registry), address(lpStakingTimeMock), surplusRecipient_);

        assertEq(address(assetModule.LP_STAKING_TIME()), address(lpStakingTimeMock));
        assertEq(address(assetModule.REWARD_TOKEN()), address(lpStakingTimeMock.eToken()));
        assertEq(assetModule.ASSET_TYPE(), 2);
        assertEq(assetModule.REGISTRY(), address(registry));
        assertEq(assetModule.symbol(), "aSGP");
        assertEq(assetModule.name(), "Arcadia Stargate Positions");
        assertEq(assetModule.surplusRecipient(), surplusRecipient_);
    }
}
