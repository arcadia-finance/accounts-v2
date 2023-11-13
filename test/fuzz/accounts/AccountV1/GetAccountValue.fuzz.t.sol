/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getAccountValue" of contract "AccountV1".
 */
contract GetAccountValue_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAccountValue(uint128 spotValue) public {
        // Given: "exposure" is strictly smaller as "maxExposure".
        spotValue = uint128(bound(spotValue, 0, type(uint128).max - 1));

        // Set Spot Value of assets (value of stable1 is 1:1 the amount of stable1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, spotValue);

        uint256 actualValue = accountExtension.getAccountValue(address(mockERC20.stable1));

        assertEq(spotValue, actualValue);
    }
}
