/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { UniswapV4AMExtension } from "../../../utils/extensions/UniswapV4AMExtension.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";
import { UniswapV4HooksRegistryExtension } from "../../../utils/extensions/UniswapV4HooksRegistryExtension.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "UniswapV4HooksRegistry".
 */
contract Constructor_UniswapV4HooksRegistry_Fuzz_Test is UniswapV4HooksRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.owner);
        UniswapV4HooksRegistryExtension v4HooksRegistry_ =
            new UniswapV4HooksRegistryExtension(registry_, address(positionManager));
        vm.stopPrank();

        assertEq(v4HooksRegistry_.owner(), users.owner);
        assertEq(v4HooksRegistry_.REGISTRY(), registry_);
        assertEq(v4HooksRegistry_.ASSET_TYPE(), 2);
        assertEq(v4HooksRegistry_.getPositionManager(), address(positionManager));
        uniswapV4AM = UniswapV4AMExtension(v4HooksRegistry_.DEFAULT_UNISWAP_V4_AM());
        assertTrue(v4HooksRegistry_.isAssetModule(address(uniswapV4AM)));
        assertEq(uniswapV4AM.owner(), users.owner);
    }
}
