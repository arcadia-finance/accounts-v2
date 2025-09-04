/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { IAllowanceTransfer } from "../../../../lib/v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { IPositionDescriptor } from "../../../../lib/v4-periphery/src/interfaces/IPositionDescriptor.sol";
import { IWETH9 } from "../../../../lib/v4-periphery/src/interfaces/external/IWETH9.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";
import { UniswapV4HooksRegistryExtension } from "../../../utils/extensions/UniswapV4HooksRegistryExtension.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "setProtocol" of contract "UniswapV4HooksRegistry".
 */
contract SetProtocol_UniswapV4HooksRegistry_Fuzz_Test is UniswapV4HooksRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setProtocol_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.owner);
        vm.startPrank(unprivilegedAddress_);

        vm.expectRevert("UNAUTHORIZED");
        v4HooksRegistry.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_ProtocolNotAddedToReg() public {
        vm.startPrank(users.owner);
        v4HooksRegistry = new UniswapV4HooksRegistryExtension(address(registry), address(positionManagerV4));

        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        v4HooksRegistry.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_OverwriteExistingProtocol() public {
        vm.startPrank(users.owner);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        v4HooksRegistry.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Success_setProtocol() public {
        vm.startPrank(users.owner);

        // Redeploy Position Manager
        bytes memory args = abi.encode(
            poolManager,
            IAllowanceTransfer(address(permit2)),
            0,
            IPositionDescriptor(address(0)),
            IWETH9(address(weth9))
        );
        bytes memory bytecode = abi.encodePacked(vm.getCode("PositionManagerExtension.sol"), args);
        address positionManagerV4_ = Utils.deployBytecode(bytecode);

        v4HooksRegistry = new UniswapV4HooksRegistryExtension(address(registry), positionManagerV4_);

        registry.addAssetModule(address(v4HooksRegistry));
        vm.stopPrank();

        vm.prank(users.owner);
        v4HooksRegistry.setProtocol();

        assertTrue(v4HooksRegistry.inAssetModule(positionManagerV4_));
        assertTrue(registry.inRegistry(positionManagerV4_));
    }
}
