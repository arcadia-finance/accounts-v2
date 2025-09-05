/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Base_Test } from "../Base.t.sol";
import { ArcadiaAccountsFixture } from "../utils/fixtures/arcadia-accounts/ArcadiaAccountsFixture.f.sol";

/// @notice Common logic needed by all invariant tests.
abstract contract Invariant_Test is Base_Test, ArcadiaAccountsFixture {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        Base_Test.setUp();
        deployArcadiaAccounts(address(0));
    }
}
