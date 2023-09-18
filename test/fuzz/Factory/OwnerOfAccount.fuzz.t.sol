/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "ownerOfAccount" of contract "Factory".
 */
contract OwnerOfAccount_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_ownerOfAccount_NonAccount(address nonAccount) public {
        assertEq(factory.ownerOfAccount(nonAccount), address(0));
    }
}
