/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { IAllowanceTransfer } from "../../../../lib/v4-periphery-fork/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { PositionManagerExtension } from
    "../../../../test/utils/fixtures/uniswap-v4/extensions/PositionManagerExtension.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { UniswapV4AM_Fuzz_Test } from "./_UniswapV4AM.fuzz.t.sol";
import { UniswapV4AMExtension } from "../../../utils/extensions/UniswapV4AMExtension.sol";

/**
 * @notice Fuzz tests for the function "setProtocol" of contract "UniswapV4AM".
 */
contract SetProtocol_UniswapV4AM_Fuzz_Test is UniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setProtocol_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.owner);
        vm.startPrank(unprivilegedAddress_);

        vm.expectRevert("UNAUTHORIZED");
        uniswapV4AM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_ProtocolNotAddedToReg() public {
        vm.startPrank(users.owner);
        uniswapV4AM = new UniswapV4AMExtension(address(registry), address(positionManager), address(poolManager));

        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        uniswapV4AM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_OverwriteExistingProtocol() public {
        vm.startPrank(users.owner);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        uniswapV4AM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Success_setProtocol() public {
        vm.startPrank(users.owner);

        // Redeploy Position Manager
        positionManager = new PositionManagerExtension(poolManager, IAllowanceTransfer(address(1)), 0);

        UniswapV4AMExtension uniswapV4AM_ =
            new UniswapV4AMExtension(address(registry), address(positionManager), address(poolManager));
        registry.addAssetModule(address(uniswapV4AM_));
        vm.stopPrank();

        vm.prank(users.owner);
        uniswapV4AM_.setProtocol();

        assertTrue(uniswapV4AM_.inAssetModule(address(positionManager)));
        assertTrue(registry.inRegistry(address(positionManager)));
    }
}
