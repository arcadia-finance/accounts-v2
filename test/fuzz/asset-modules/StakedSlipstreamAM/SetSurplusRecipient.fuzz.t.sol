/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setSurplusRecipient" of contract "StakedSlipstreamAM".
 */
contract SetSurplusRecipient_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
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
        stakedSlipstreamAM.setSurplusRecipient(recipient);
    }

    function testFuzz_Revert_setSurplusRecipient_Zero() public {
        // Given: The recipient is the zero address.
        // When: The Owner sets the recipient.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.RecipientNotValid.selector);
        stakedSlipstreamAM.setSurplusRecipient(address(0));
    }

    function testFuzz_Revert_setSurplusRecipient_Self() public {
        // Given: The recipient is the Asset Module itself.
        // When: The Owner sets the recipient.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.RecipientNotValid.selector);
        stakedSlipstreamAM.setSurplusRecipient(address(stakedSlipstreamAM));
    }

    function testFuzz_Success_setSurplusRecipient(address recipient) public {
        // Given: The recipient is neither the zero address nor the Asset Module.
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(stakedSlipstreamAM));

        // When: The Owner sets the recipient.
        // Then: The SurplusRecipientSet event is emitted.
        vm.prank(users.owner);
        vm.expectEmit(address(stakedSlipstreamAM));
        emit StakedSlipstreamAM.SurplusRecipientSet(recipient);
        stakedSlipstreamAM.setSurplusRecipient(recipient);

        // And: The recipient is stored.
        assertEq(stakedSlipstreamAM.surplusRecipient(), recipient);
    }
}
