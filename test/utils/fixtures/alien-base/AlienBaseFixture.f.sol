/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import {
    INonfungiblePositionManagerExtension
} from "../../../utils/fixtures/uniswap-v3/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3Factory } from "../../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3Factory.sol";
import { QuoterV2Fixture } from "../../../utils/fixtures/uniswap-v3/QuoterV2Fixture.f.sol";
import { SwapRouter02Fixture } from "../../../utils/fixtures/swap-router-02/SwapRouter02Fixture.f.sol";
import { UniswapV3Fixture } from "../../../utils/fixtures/uniswap-v3/UniswapV3Fixture.f.sol";

contract AlienBaseFixture is UniswapV3Fixture, QuoterV2Fixture, SwapRouter02Fixture {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override(UniswapV3Fixture) {
        // Replace addresses here with the addresses of AlienBase.
        uniswapV3Factory = IUniswapV3Factory(0x0Fd83557b2be93617c9C1C1B6fd549401C74558C);
        nonfungiblePositionManager = INonfungiblePositionManagerExtension(0xB7996D1ECD07fB227e8DcA8CD5214bDfb04534E5);

        UniswapV3Fixture.setUp();

        deployQuoterV2(address(uniswapV3Factory), address(weth9));

        SwapRouter02Fixture.deploySwapRouter02(
            address(0), address(uniswapV3Factory), address(nonfungiblePositionManager), address(weth9)
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
}
