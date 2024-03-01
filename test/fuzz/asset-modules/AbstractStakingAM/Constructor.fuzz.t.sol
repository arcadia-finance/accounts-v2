/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingAM_Fuzz_Test } from "./_AbstractStakingAM.fuzz.t.sol";

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
    function testFuzz_Success_deployment(address registry_, string memory name_, string memory symbol_) public {
        vm.startPrank(users.creatorAddress);
        StakingAMMock assetModule_ = new StakingAMMock(registry_, name_, symbol_, address(rewardToken));
        vm.stopPrank();

        assertEq(assetModule_.REGISTRY(), registry_);
        assertEq(assetModule_.name(), name_);
        assertEq(assetModule_.symbol(), symbol_);
        assertEq(assetModule_.ASSET_TYPE(), 2);
    }
}
