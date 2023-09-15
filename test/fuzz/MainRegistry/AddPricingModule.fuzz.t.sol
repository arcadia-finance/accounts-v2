/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "addPricingModule" of contract "MainRegistry".
 */
contract AddPricingModule_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addPricingModule_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not users.creatorAddress
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addPricingModule

        // Then: addPricingModule should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        mainRegistryExtension.addPricingModule(address(erc20PricingModule));
        vm.stopPrank();
    }

    function testFuzz_Revert_addPricingModule_AddExistingPricingModule() public {
        // Given: All necessary contracts deployed on setup

        // When: users.creatorAddress calls addPricingModule for address(erc20PricingModule)
        // Then: addPricingModule should revert with "MR_APM: PriceMod. not unique"
        vm.prank(users.creatorAddress);
        vm.expectRevert("MR_APM: PriceMod. not unique");
        mainRegistryExtension.addPricingModule(address(erc20PricingModule));
    }

    function testFuzz_Success_addPricingModule(address pricingModule) public {
        // Given: pricingModule is different from previously deployed pricing modules.
        vm.assume(pricingModule != address(erc20PricingModule));
        vm.assume(pricingModule != address(floorERC721PricingModule));
        vm.assume(pricingModule != address(floorERC1155PricingModule));
        vm.assume(pricingModule != address(uniV3PricingModule));

        // When: users.creatorAddress calls addPricingModule for address(erc20PricingModule)
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit PricingModuleAdded(pricingModule);
        mainRegistryExtension.addPricingModule(pricingModule);
        vm.stopPrank();

        // Then: isPricingModule for address(erc20PricingModule) should return true
        assertTrue(mainRegistryExtension.isPricingModule(pricingModule));
    }
}
