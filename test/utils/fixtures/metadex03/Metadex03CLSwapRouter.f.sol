/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Test } from "../../../../lib/forge-std/src/Test.sol";

import { ICLSwapRouter } from "../slipstream/interfaces/ICLSwapRouter.sol";
import { Utils } from "../../Utils.sol";

contract Metadex03CLSwapRouterFixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    // forge-lint: disable-next-line(mixed-case-variable)
    ICLSwapRouter internal metadex03CLSwapRouter;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function deployMetadex03SwapRouter(address factory_, address weth9_) public {
        // Get the bytecode of the metadex03 SwapRouter.
        bytes memory args = abi.encode(factory_, weth9_);
        // forge-lint: disable-next-item(encode-packed-collision)
        bytes memory bytecode = abi.encodePacked(vm.getCode("Metadex03CLSwapRouterExtension.sol"), args);

        address swapRouter_ = Utils.deployBytecode(bytecode);
        metadex03CLSwapRouter = ICLSwapRouter(swapRouter_);
    }
}
