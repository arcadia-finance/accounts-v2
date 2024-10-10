/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { PoolKey } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolKey.sol";
import { TickMath } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/TickMath.sol";
import { UniswapV4AMExtension } from "../../../../test/utils/extensions/UniswapV4AMExtension.sol";
import { UniswapV4Fixture } from "../../../utils/fixtures/uniswap-v4/UniswapV4Fixture.f.sol";
import { UniswapV4HooksRegistryExtension } from "../../../../test/utils/extensions/UniswapV4HooksRegistryExtension.sol";

/**
 * @notice Common logic needed by all "UniswapV4AM" fuzz tests.
 */
abstract contract UniswapV4HooksRegistry_Fuzz_Test is Fuzz_Test, UniswapV4Fixture {
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    UniswapV4AMExtension internal uniswapV4AM;
    UniswapV4HooksRegistryExtension internal v4HooksRegistry;
    PoolKey internal stablePoolKey;
    PoolKey internal randomPoolKey;

    ERC20 token0;
    ERC20 token1;

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

        // Deploy V4 default AM and HooksRegistry
        vm.startPrank(users.owner);
        uniswapV4AM = new UniswapV4AMExtension(address(registry), address(positionManager), address(poolManager));
        v4HooksRegistry =
            new UniswapV4HooksRegistryExtension(address(registry), address(positionManager), address(uniswapV4AM));
        registry.addAssetModule(address(v4HooksRegistry));
        v4HooksRegistry.setProtocol();
        vm.stopPrank();
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/
}
