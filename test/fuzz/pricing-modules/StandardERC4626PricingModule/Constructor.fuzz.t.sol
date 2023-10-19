/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, StandardERC4626PricingModule_Fuzz_Test } from "./_StandardERC4626PricingModule.fuzz.t.sol";

import { ERC4626PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "StandardERC4626PricingModule".
 */
contract Constructor_StandardERC4626PricingModule_Fuzz_Test is StandardERC4626PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address mainRegistry_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(users.creatorAddress);
        ERC4626PricingModuleExtension erc4626PricingModule_ = new ERC4626PricingModuleExtension(
            mainRegistry_
        );
        vm.stopPrank();

        assertEq(erc4626PricingModule_.MAIN_REGISTRY(), mainRegistry_);
        assertEq(erc4626PricingModule_.ASSET_TYPE(), 0);
        assertEq(erc4626PricingModule_.riskManager(), users.creatorAddress);
        assertFalse(erc4626PricingModule_.getPrimaryFlag());
    }
}
