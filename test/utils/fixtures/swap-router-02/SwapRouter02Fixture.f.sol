/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../../../lib/forge-std/src/Test.sol";

import { ISwapRouter02 } from "./interfaces/ISwapRouter02.sol";
import { Utils } from "../../../utils/Utils.sol";

contract SwapRouter02Fixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ISwapRouter02 internal swapRouter;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function deploySwapRouter02(address factoryV2_, address factoryV3_, address positionManager_, address weth9_)
        public
    {
        // Get the bytecode of the UniswapV3PoolExtension.
        bytes memory args = abi.encode();
        bytes memory bytecode = abi.encodePacked(vm.getCode("UniswapV3PoolExtension.sol"), args);
        bytes32 poolExtensionInitCodeHash = keccak256(bytecode);

        // Get the bytecode of the SwapRouterExtension.
        args = abi.encode(factoryV2_, factoryV3_, positionManager_, weth9_);
        bytecode = abi.encodePacked(vm.getCode("SwapRouter02.sol"), args);

        // Overwrite constant in bytecode of SwapRouter.
        // -> Replace the code hash of UniswapV3Pool.sol with the code hash of UniswapV3PoolExtension.sol
        bytes32 POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytecode = Utils.veryBadBytesReplacer(bytecode, POOL_INIT_CODE_HASH, poolExtensionInitCodeHash);

        address swapRouter_ = Utils.deployBytecode(bytecode);
        swapRouter = ISwapRouter02(swapRouter_);
    }
}
