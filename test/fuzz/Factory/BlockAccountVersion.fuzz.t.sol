/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Factory } from "../../../src/Factory.sol";
import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";
import { FactoryErrors } from "../../../src/libraries/Errors.sol";
/**
 * @notice Fuzz tests for the function "blockAccountVersion" of contract "Factory".
 */

contract BlockAccountVersion_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_blockAccountVersion_NonOwner(uint256 accountVersion, address unprivilegedAddress_)
        public
    {
        vm.assume(unprivilegedAddress_ != users.owner);

        uint256 currentVersion = factory.latestAccountVersion();
        accountVersion = bound(accountVersion, 1, currentVersion);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        factory.blockAccountVersion(accountVersion);
        vm.stopPrank();
    }

    function testFuzz_Revert_blockAccountVersion_BlockZeroVersion() public {
        vm.startPrank(users.owner);
        vm.expectRevert(FactoryErrors.InvalidAccountVersion.selector);
        factory.blockAccountVersion(0);
        vm.stopPrank();
    }

    function testFuzz_Revert_blockAccountVersion_BlockNonExistingAccountVersion(uint256 accountVersion) public {
        uint256 currentVersion = factory.latestAccountVersion();
        accountVersion = bound(accountVersion, currentVersion + 1, type(uint256).max);

        vm.startPrank(users.owner);
        vm.expectRevert(FactoryErrors.InvalidAccountVersion.selector);
        factory.blockAccountVersion(accountVersion);
        vm.stopPrank();
    }

    function testFuzz_Success_blockAccountVersion(uint256 accountVersion) public {
        uint256 currentVersion = factory.latestAccountVersion();
        accountVersion = bound(accountVersion, 1, currentVersion);

        vm.startPrank(users.owner);
        vm.expectEmit(true, true, true, true);
        emit Factory.AccountVersionBlocked(uint88(accountVersion));
        factory.blockAccountVersion(accountVersion);
        vm.stopPrank();

        assertTrue(factory.accountVersionBlocked(accountVersion));
    }
}
