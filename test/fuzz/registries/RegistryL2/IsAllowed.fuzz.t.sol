/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryL2_Fuzz_Test } from "./_RegistryL2.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "RegistryL2".
 */
contract IsAllowed_RegistryL2_Fuzz_Test is RegistryL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Negative_UnknownAsset(address randomAsset, uint256 assetId) public {
        vm.assume(randomAsset != address(mockERC20.stable1));
        vm.assume(randomAsset != address(mockERC20.stable2));
        vm.assume(randomAsset != address(mockERC20.token1));
        vm.assume(randomAsset != address(mockERC20.token2));
        vm.assume(randomAsset != address(mockERC721.nft1));
        vm.assume(randomAsset != address(mockERC1155.sft1));

        assertFalse(registry.isAllowed(randomAsset, assetId));
    }

    function testFuzz_Success_isAllowed_Negative_NonAllowedAsset() public {
        assertFalse(registry.isAllowed(address(mockERC1155.sft1), 2));
    }

    function testFuzz_Success_isAllowed_Positive(uint256 assetId) public {
        assertTrue(registry.isAllowed(address(mockERC20.stable1), assetId));
    }
}
