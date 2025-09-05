/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Test } from "../../../../lib/forge-std/src/Test.sol";

import { ICLSwapRouter } from "./interfaces/ICLSwapRouter.sol";
import { Utils } from "../../../utils/Utils.sol";

contract CLSwapRouterFixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ICLSwapRouter internal clSwapRouter;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function deploySwapRouter(address factory_, address weth9_) public {
        // Get the bytecode of the SwapRouterExtension.
        bytes memory args = abi.encode(factory_, weth9_);
        bytes memory bytecode = abi.encodePacked(vm.getCode("SwapRouter.sol"), args);

        address swapRouter_ = Utils.deployBytecode(bytecode);
        clSwapRouter = ICLSwapRouter(swapRouter_);
    }
}
