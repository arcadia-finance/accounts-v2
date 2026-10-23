/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";
import { StakedSlipstreamAMExtension } from "../../../utils/extensions/StakedSlipstreamAMExtension.sol";

/**
 * @notice Fuzz tests for the constructor of contract "StakedSlipstreamAM".
 */
contract Constructor_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedSlipstreamAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_constructor_RecipientNotValid(address owner_, address registry_) public {
        // Given: The recipient is the zero address.
        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(StakedSlipstreamAM.RecipientNotValid.selector);
        new StakedSlipstreamAMExtension(
            owner_, registry_, address(slipstreamPositionManager), address(voter), AERO, address(0)
        );
    }

    function testFuzz_Success_constructor(address owner_, address registry_, address surplusRecipient_) public {
        // Given: The recipient is not the zero address.
        vm.assume(surplusRecipient_ != address(0));

        // When: The Asset Module is deployed.
        stakedSlipstreamAM = new StakedSlipstreamAMExtension(
            owner_, registry_, address(slipstreamPositionManager), address(voter), AERO, surplusRecipient_
        );

        // Then: The constructor arguments are stored.
        assertEq(stakedSlipstreamAM.owner(), owner_);
        assertEq(stakedSlipstreamAM.REGISTRY(), registry_);
        assertEq(stakedSlipstreamAM.getNonfungiblePositionManager(), address(slipstreamPositionManager));
        assertEq(stakedSlipstreamAM.getAeroVoter(), address(voter));
        assertEq(address(stakedSlipstreamAM.REWARD_TOKEN()), AERO);

        // And: The Slipstream Factory is read from the Position Manager.
        assertEq(stakedSlipstreamAM.getCLFactory(), address(cLFactory));

        // And: The ERC721 identity is the inherited one.
        assertEq(stakedSlipstreamAM.name(), "Arcadia Staked Slipstream Positions");
        assertEq(stakedSlipstreamAM.symbol(), "aSSLIPP");

        // And: The recipient is stored.
        assertEq(stakedSlipstreamAM.surplusRecipient(), surplusRecipient_);
    }
}
