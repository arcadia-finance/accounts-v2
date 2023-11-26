/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WETH9Fixture } from "../weth9/WETH9Fixture.f.sol";

import { INonfungiblePositionManagerExtension } from "./extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3Factory } from "./extensions/interfaces/IUniswapV3Factory.sol";
import { Utils } from "../../../utils/Utils.sol";

contract UniswapV3Fixture is WETH9Fixture {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IUniswapV3Factory internal uniswapV3Factory;
    INonfungiblePositionManagerExtension internal nonfungiblePositionManager;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        WETH9Fixture.setUp();

        // Since Uniswap uses different a pragma version as us, we can't directly deploy the code
        // -> use getCode to get bytecode from artefacts and deploy directly.

        // Deploy the uniswapV3Factory.
        bytes memory args = abi.encode();
        bytes memory bytecode = abi.encodePacked(vm.getCode("UniswapV3FactoryExtension.sol"), args);
        address uniswapV3Factory_ = Utils.deployBytecode(bytecode);
        uniswapV3Factory = IUniswapV3Factory(uniswapV3Factory_);
        // Add fee 100 with tickspacing 1.
        uniswapV3Factory.enableFeeAmount(100, 1);

        // Get the bytecode of the UniswapV3PoolExtension.
        args = abi.encode();
        bytecode = abi.encodePacked(vm.getCode("UniswapV3PoolExtension.sol"), args);
        bytes32 poolExtensionInitCodeHash = keccak256(bytecode);

        // Get the bytecode of NonfungiblePositionManagerExtension, pass zero address for the NonfungibleTokenPositionDescriptor.
        args = abi.encode(uniswapV3Factory_, address(weth9), address(0));
        bytecode = abi.encodePacked(vm.getCode("NonfungiblePositionManagerExtension.sol"), args);

        // Overwrite constant in bytecode of NonfungiblePositionManager.
        // -> Replace the code hash of UniswapV3Pool.sol with the code hash of UniswapV3PoolExtension.sol
        bytes32 POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytecode = Utils.veryBadBytesReplacer(bytecode, POOL_INIT_CODE_HASH, poolExtensionInitCodeHash);

        // Deploy NonfungiblePositionManagerExtension with modified bytecode.
        address nonfungiblePositionManager_ = Utils.deployBytecode(bytecode);
        nonfungiblePositionManager = INonfungiblePositionManagerExtension(nonfungiblePositionManager_);
    }
}
