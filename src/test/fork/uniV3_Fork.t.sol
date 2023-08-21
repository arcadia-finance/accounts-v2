/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_Fork_Test } from "./Base_Fork.t.sol";
import { IPricingModule_UsdOnly } from "../../interfaces/IPricingModule_UsdOnly.sol";
import { ERC20Mock } from "../../mockups/ERC20SolmateMock.sol";
import { IUniswapV3PoolExtension } from "../utils/interfaces.sol";
import { INonfungiblePositionManagerExtension } from "../utils/interfaces.sol";

contract UniV3_Fork_Test is Base_Fork_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    address public uniV3NonfungiblePositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    INonfungiblePositionManagerExtension public uniV3 =
        INonfungiblePositionManagerExtension(uniV3NonfungiblePositionManager);

    /* ///////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function createPool(address token0, address token1, uint160 sqrtPriceX96, uint16 observationCardinality)
        public
        returns (IUniswapV3PoolExtension pool)
    {
        address poolAddress = uniV3.createAndInitializePoolIfNecessary(token0, token1, 100, sqrtPriceX96); // Set initial price to lowest possible price.
        pool = IUniswapV3PoolExtension(poolAddress);
        pool.increaseObservationCardinalityNext(observationCardinality);
    }

    function createToken(address deployer_, uint8 decimals) public returns (ERC20Mock token) {
        vm.prank(deployer_);
        token = new ERC20Mock('Token', 'TOK', decimals);
    }

    function createToken() public returns (ERC20Mock token) {
        token = createToken(0xbA32A3D407353FC3adAA6f7eC6264Df5bCA51c4b, 18);
    }

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_Fork_Test) {
        Base_Fork_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/
}
