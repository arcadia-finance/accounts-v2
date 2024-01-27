/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StandardERC4626AM_Fuzz_Test } from "./_StandardERC4626AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "StandardERC4626AM".
 */
contract IsAllowed_StandardERC4626AM_Fuzz_Test is StandardERC4626AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Negative(address randomAsset, uint256 assetId) public {
        assertFalse(erc4626AM.isAllowed(randomAsset, assetId));
    }

    function testFuzz_Success_isAllowed_Positive(uint256 assetId) public {
        vm.prank(users.creatorAddress);
        erc4626AM.addAsset(address(ybToken1));

        assertTrue(erc4626AM.isAllowed(address(ybToken1), assetId));
    }
}
