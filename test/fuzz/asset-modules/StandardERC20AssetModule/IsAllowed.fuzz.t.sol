/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StandardERC20AssetModule_Fuzz_Test } from "./_StandardERC20AssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "StandardERC20AssetModule".
 */
contract IsAllowed_StandardERC20AssetModule_Fuzz_Test is StandardERC20AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC20AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Positive(uint256 assetId) public {
        assertTrue(erc20AssetModule.isAllowed(address(mockERC20.stable1), assetId));
    }

    function testFuzz_Success_isAllowed_Negative(address randomAsset, uint256 assetId) public {
        vm.assume(randomAsset != address(mockERC20.stable1));
        vm.assume(randomAsset != address(mockERC20.stable2));
        vm.assume(randomAsset != address(mockERC20.token1));
        vm.assume(randomAsset != address(mockERC20.token2));

        assertFalse(erc20AssetModule.isAllowed(randomAsset, assetId));
    }
}
