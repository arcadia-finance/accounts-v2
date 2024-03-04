/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20PrimaryAM_Fuzz_Test } from "./_ERC20PrimaryAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "ERC20PrimaryAM".
 */
contract IsAllowed_ERC20PrimaryAM_Fuzz_Test is ERC20PrimaryAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ERC20PrimaryAM_Fuzz_Test.setUp();
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
