/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test, StakingAM } from "./_AbstractStakingAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setSurplusRecipient" of contract "StakingAM".
 */
contract SetSurplusRecipient_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_setSurplusRecipient_NotOwner(address sender, address recipient) public {
        // Given: The sender is not the Owner.
        vm.assume(sender != users.owner);

        // When: The sender sets the recipient.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert("UNAUTHORIZED");
        stakingAM.setSurplusRecipient(recipient);
    }

    function testFuzz_Revert_setSurplusRecipient_Zero() public {
        // Given: The recipient is the zero address.
        // When: The Owner sets the recipient.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakingAM.RecipientNotValid.selector);
        stakingAM.setSurplusRecipient(address(0));
    }

    function testFuzz_Revert_setSurplusRecipient_Self() public {
        // Given: The recipient is the Asset Module itself.
        // When: The Owner sets the recipient.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakingAM.RecipientNotValid.selector);
        stakingAM.setSurplusRecipient(address(stakingAM));
    }

    function testFuzz_Success_setSurplusRecipient(address recipient) public {
        // Given: The recipient is neither the zero address nor the Asset Module.
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(stakingAM));

        // When: The Owner sets the recipient.
        // Then: The SurplusRecipientSet event is emitted.
        vm.prank(users.owner);
        vm.expectEmit(address(stakingAM));
        emit StakingAM.SurplusRecipientSet(recipient);
        stakingAM.setSurplusRecipient(recipient);

        // And: The recipient is stored.
        assertEq(stakingAM.surplusRecipient(), recipient);
    }
}
