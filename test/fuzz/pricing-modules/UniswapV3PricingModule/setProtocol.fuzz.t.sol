/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3Fixture, UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

import { UniswapV3PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "setProtocol" of contract "UniswapV3PricingModule".
 */
contract SetProtocol_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();

        deployUniswapV3PricingModule(address(nonfungiblePositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setProtocol_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);

        vm.expectRevert("UNAUTHORIZED");
        uniV3PricingModule.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_ProtocolNotAddedToMainreg() public {
        vm.prank(users.creatorAddress);
        uniV3PricingModule =
        new UniswapV3PricingModuleExtension(address(mainRegistryExtension), users.creatorAddress, address(nonfungiblePositionManager));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("MR: Only PriceMod.");
        uniV3PricingModule.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_OverwriteExistingProtocol() public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("MR_AA: Asset already in mainreg");
        uniV3PricingModule.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Success_setProtocol() public {
        vm.startPrank(users.creatorAddress);
        uniV3PricingModule =
        new UniswapV3PricingModuleExtension(address(mainRegistryExtension), users.creatorAddress, address(nonfungiblePositionManagerMock));
        mainRegistryExtension.addPricingModule(address(uniV3PricingModule));
        vm.stopPrank();

        vm.prank(users.creatorAddress);
        uniV3PricingModule.setProtocol();

        assertTrue(mainRegistryExtension.inMainRegistry(address(nonfungiblePositionManagerMock)));
    }
}
