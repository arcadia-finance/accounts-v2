/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test } from "./_AbstractStakingAM.fuzz.t.sol";
import { StakingAM } from "../../../../src/asset-modules/abstracts/AbstractStakingAM.sol";
import { StakingAMMock } from "../../../utils/mocks/asset-modules/StakingAMMock.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "StakingAM".
 */
contract Constructor_StakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_constructor_RecipientNotValid(
        address owner_,
        address registry_,
        string memory name_,
        string memory symbol_
    ) public {
        // Given: The recipient is the zero address.
        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(StakingAM.RecipientNotValid.selector);
        new StakingAMMock(owner_, registry_, name_, symbol_, address(rewardToken), address(0));
    }

    function testFuzz_Success_constructor(
        address owner_,
        address registry_,
        string memory name_,
        string memory symbol_,
        address surplusRecipient_
    ) public {
        // Given: The recipient is not the zero address.
        vm.assume(surplusRecipient_ != address(0));

        // When: The Asset Module is deployed.
        StakingAMMock assetModule_ =
            new StakingAMMock(owner_, registry_, name_, symbol_, address(rewardToken), surplusRecipient_);

        // Then: The constructor arguments are stored.
        assertEq(assetModule_.owner(), owner_);
        assertEq(assetModule_.REGISTRY(), registry_);
        assertEq(assetModule_.name(), name_);
        assertEq(assetModule_.symbol(), symbol_);
        assertEq(assetModule_.ASSET_TYPE(), 2);
        assertEq(assetModule_.surplusRecipient(), surplusRecipient_);
    }
}
