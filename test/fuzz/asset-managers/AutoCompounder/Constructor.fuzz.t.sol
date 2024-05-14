/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AutoCompounder_Fuzz_Test, AutoCompounderExtension } from "./_AutoCompounder.fuzz.t.sol";
import { ERC721 } from "../../../utils/mocks/tokens/ERC721Mock.sol";

/**
 * @notice Fuzz tests for the function "Constructor" of contract "AutoCompounder".
 */
contract Constructor_AutoCompounder_Fuzz_Test is AutoCompounder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AutoCompounder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_Constructor() public {
        vm.prank(users.creatorAddress);
        autoCompounder = new AutoCompounderExtension(
            address(registryExtension),
            address(uniswapV3Factory),
            address(nonfungiblePositionManager),
            address(swapRouter),
            1000
        );

        assertEq(address(autoCompounder.UNI_V3_FACTORY()), address(uniswapV3Factory));
        assertEq(address(autoCompounder.REGISTRY()), address(registryExtension));
        assertEq(address(autoCompounder.NONFUNGIBLE_POSITIONMANAGER()), address(nonfungiblePositionManager));
        assertEq(address(autoCompounder.SWAP_ROUTER()), address(swapRouter));
        // Sqrt of (BIPS + 1000) * BIPS is 10488
        assertEq(autoCompounder.MAX_SQRT_PRICE_DEVIATION(), 10_488);
    }
}
