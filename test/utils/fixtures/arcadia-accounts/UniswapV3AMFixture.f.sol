/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Test } from "../../../Base.t.sol";

import { UniswapV3AMExtension } from "../../extensions/UniswapV3AMExtension.sol";
import { Utils } from "../../Utils.sol";

contract UniswapV3AMFixture is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    UniswapV3AMExtension internal uniV3AM;

    /*//////////////////////////////////////////////////////////////////////////
                                  HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function deployUniswapV3AM(address nonfungiblePositionManager_) internal {
        // Get the bytecode of the UniswapV3PoolExtension.
        bytes memory args = abi.encode();
        bytes memory bytecode = abi.encodePacked(vm.getCode("UniswapV3PoolExtension.sol"), args);
        bytes32 poolExtensionInitCodeHash = keccak256(bytecode);

        // Get the bytecode of UniswapV3AMExtension.
        args = abi.encode(address(registry), nonfungiblePositionManager_);
        bytecode = abi.encodePacked(vm.getCode("UniswapV3AMExtension.sol:UniswapV3AMExtension"), args);

        // Overwrite constant in bytecode of NonfungiblePositionManager.
        // -> Replace the code hash of UniswapV3Pool.sol with the code hash of UniswapV3PoolExtension.sol
        bytes32 POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytecode = Utils.veryBadBytesReplacer(bytecode, POOL_INIT_CODE_HASH, poolExtensionInitCodeHash);

        // Deploy UniswapV3PoolExtension with modified bytecode.
        vm.prank(users.owner);
        address uniV3AssetModule_ = Utils.deployBytecode(bytecode);
        uniV3AM = UniswapV3AMExtension(uniV3AssetModule_);

        vm.label({ account: address(uniV3AM), newLabel: "Uniswap V3 Asset Module" });

        // Add the Asset Module to the Registry.
        vm.startPrank(users.owner);
        registry.addAssetModule(address(uniV3AM));
        uniV3AM.setProtocol();
        vm.stopPrank();
    }
}
