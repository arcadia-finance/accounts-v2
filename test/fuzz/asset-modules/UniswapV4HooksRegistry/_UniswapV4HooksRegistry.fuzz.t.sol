/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { BaseHook } from "../../../../lib/v4-periphery-fork/src/base/hooks/BaseHook.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { UniswapV4AMExtension } from "../../../../test/utils/extensions/UniswapV4AMExtension.sol";
import { UniswapV4Fixture } from "../../../utils/fixtures/uniswap-v4/UniswapV4Fixture.f.sol";
import { UniswapV4HooksRegistry } from "../../../../src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol";

/**
 * @notice Common logic needed by all "UniswapV4AM" fuzz tests.
 */
abstract contract UniswapV4HooksRegistry_Fuzz_Test is Fuzz_Test, UniswapV4Fixture {
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    UniswapV4AMExtension internal uniswapV4AM;
    UniswapV4HooksRegistry internal v4HooksRegistry;
    PoolKey internal stablePoolKey;
    PoolKey internal randomPoolKey;

    ERC20 token0;
    ERC20 token1;

    uint256 internal constant INT256_MAX = 2 ** 255 - 1;
    // While the true minimum value of an int256 is 2 ** 255, Solidity overflows on a negation (since INT256_MAX is one less).
    // -> This true minimum value will overflow and revert.
    uint256 internal constant INT256_MIN = 2 ** 255 - 1;

    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, UniswapV4Fixture) {
        Fuzz_Test.setUp();
        // Deploy fixture for UniswapV4
        vm.startPrank(users.owner);
        UniswapV4Fixture.setUp();
        vm.stopPrank();

        // Initializes a pool
        stablePoolKey = initializePool(
            address(mockERC20.stable1),
            address(mockERC20.stable2),
            TickMath.getSqrtPriceAtTick(0),
            address(validHook),
            500,
            1
        );

        // Deploy Asset-Module
        vm.startPrank(users.owner);
        uniswapV4AM = new UniswapV4AMExtension(address(registry), address(positionManager), address(stateView));
        //v4HooksRegistry
        registry.addAssetModule(address(uniswapV4AM));
        uniswapV4AM.setProtocol();
        vm.stopPrank();
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/
}
