/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

import { Factory } from "../../../src/Factory.sol";

/**
 * @notice Fuzz tests for the function "allAccountsLength" of contract "Factory".
 */
contract AllAccountsLength_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_allAccountsLength_AccountIdStartFromZero() public {
        Factory factory_ = new Factory();

        assertEq(factory_.allAccountsLength(), 0);
    }
}
