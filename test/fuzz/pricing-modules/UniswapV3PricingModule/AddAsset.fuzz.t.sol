/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3Fixture, UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

import { UniswapV3PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "addAsset" of contract "UniswapV3PricingModule".
 */
contract AddAsset_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_, address asset) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);

        vm.expectRevert("UNAUTHORIZED");
        uniV3PricingModule.addAsset(asset);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PMUV3_AA: already added");
        uniV3PricingModule.addAsset(address(nonfungiblePositionManager));
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_MainRegistryReverts() public {
        vm.prank(users.creatorAddress);
        uniV3PricingModule =
        new UniswapV3PricingModuleExtension(address(mainRegistryExtension), address(oracleHub), users.creatorAddress);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("MR: Only PriceMod.");
        uniV3PricingModule.addAsset(address(nonfungiblePositionManager));
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset() public {
        // Deploy UniV3 again to have new contract addresses, not yet added into the MainRegistry.
        UniswapV3Fixture.setUp();

        vm.prank(users.creatorAddress);
        uniV3PricingModule.addAsset(address(nonfungiblePositionManager));

        address factory_ = nonfungiblePositionManager.factory();
        assertTrue(uniV3PricingModule.inPricingModule(address(nonfungiblePositionManager)));
        assertEq(uniV3PricingModule.assetsInPricingModule(1), address(nonfungiblePositionManager));
        assertEq(uniV3PricingModule.assetToV3Factory(address(nonfungiblePositionManager)), factory_);
    }
}
