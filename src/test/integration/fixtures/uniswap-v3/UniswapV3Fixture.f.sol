/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Utils } from "../../../utils/Utils.sol";
import { WETH9Fixture } from "../weth9/WETH9Fixture.f.sol";

import { INonfungiblePositionManagerExtension } from
    "../../../../test_old/interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3Factory } from "../../../../test_old/interfaces/IUniswapV3Factory.sol";

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

        // Deploy the nonfungiblePositionManager, pass zero address for the NonfungibleTokenPositionDescriptor.
        args = abi.encode(uniswapV3Factory_, address(weth9), address(0));
        bytecode = abi.encodePacked(vm.getCode("NonfungiblePositionManagerExtension.sol"), args);
        address nonfungiblePositionManager_ = Utils.deployBytecode(bytecode);
        nonfungiblePositionManager = INonfungiblePositionManagerExtension(nonfungiblePositionManager_);
    }
}
