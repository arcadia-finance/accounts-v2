/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "./Fuzz.t.sol";
import { AccountV1 } from "../../AccountV1.sol";
import { AccountVariableVersion } from "../../mockups/AccountVariableVersion.sol";

contract Factory_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                          Account MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testFuzz_createAccount_DeployAccountWithNoCreditor(uint256 salt) public {
        // We assume that salt > 0 as we already deployed a Account with all inputs to 0
        vm.assume(salt > 0);
        uint256 amountBefore = factory.allAccountsLength();

        vm.expectEmit();
        emit Transfer(address(0), address(this), amountBefore + 1);
        vm.expectEmit(false, true, true, true);
        emit AccountUpgraded(address(0), 0, 1);

        // Here we create a Account with no specific trusted creditor
        address actualDeployed = factory.createAccount(salt, 0, address(0), address(0));

        assertEq(amountBefore + 1, factory.allAccountsLength());
        assertEq(actualDeployed, factory.allAccounts(factory.allAccountsLength() - 1));
        assertEq(factory.accountIndex(actualDeployed), (factory.allAccountsLength()));
        assertEq(AccountV1(actualDeployed).trustedCreditor(), address(0));
        assertEq(AccountV1(actualDeployed).isTrustedCreditorSet(), false);
        assertEq(AccountV1(actualDeployed).owner(), address(this));
    }

    function testFuzz_createAccount_DeployAccountWithCreditor(uint256 salt) public {
        // We assume that salt > 0 as we already deployed a Account with all inputs to 0
        vm.assume(salt > 0);
        uint256 amountBefore = factory.allAccountsLength();

        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditorWithParamsInit), Constants.initLiquidator);
        vm.expectEmit();
        emit Transfer(address(0), address(this), amountBefore + 1);
        vm.expectEmit(false, true, true, true);
        emit AccountUpgraded(address(0), 0, 1);

        // Here we create a Account by specifying the trusted creditor address
        address actualDeployed = factory.createAccount(salt, 0, address(0), address(trustedCreditorWithParamsInit));

        assertEq(amountBefore + 1, factory.allAccountsLength());
        assertEq(actualDeployed, factory.allAccounts(factory.allAccountsLength() - 1));
        assertEq(factory.accountIndex(actualDeployed), (factory.allAccountsLength()));
        assertEq(AccountV1(actualDeployed).trustedCreditor(), address(trustedCreditorWithParamsInit));
        assertEq(AccountV1(actualDeployed).isTrustedCreditorSet(), true);
    }

    function testFuzz_createAccount_DeployNewProxyWithLogicOwner(uint256 salt, address sender) public {
        // We assume that salt > 0 as we already deployed a Account with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender != address(0));
        uint256 amountBefore = factory.allAccountsLength();
        vm.prank(sender);
        address actualDeployed = factory.createAccount(salt, 0, address(0), address(0));
        assertEq(amountBefore + 1, factory.allAccountsLength());
        assertEq(AccountV1(actualDeployed).owner(), address(sender));
    }

    function testFuzz_createAccount_CreationCannotBeFrontRunnedWithIdenticalSalt(
        uint256 salt,
        address sender0,
        address sender1
    ) public {
        // We assume that salt > 0 as we already deployed a Account with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender0 != sender1);
        vm.assume(sender0 != address(0));
        vm.assume(sender1 != address(0));

        //Broadcast changes the tx.origin, prank only changes the msg.sender, not tx.origin
        vm.broadcast(sender0);
        address proxy0 = factory.createAccount(salt, 0, address(0), address(0));

        vm.broadcast(sender1);
        address proxy1 = factory.createAccount(salt, 0, address(0), address(0));

        assertTrue(proxy0 != proxy1);
    }

    function testFuzz_Revert_createAccount_CreateNonExistingAccountVersion(uint16 accountVersion) public {
        uint256 currentVersion = factory.latestAccountVersion();
        vm.assume(accountVersion > currentVersion);

        vm.expectRevert("FTRY_CV: Unknown Account version");
        factory.createAccount(
            uint256(keccak256(abi.encodePacked(accountVersion, block.timestamp))),
            accountVersion,
            address(0),
            address(0)
        );
    }

    function testFuzz_Revert_createAccount_FromBlockedVersion(
        uint8 accountVersion,
        uint8 versionsToMake,
        uint8[] calldata versionsToBlock
    ) public {
        AccountVariableVersion account_ = new AccountVariableVersion(0);

        vm.assume(versionsToBlock.length < 10 && versionsToBlock.length > 0);
        vm.assume(uint256(versionsToMake) + 1 < type(uint8).max);
        vm.assume(accountVersion <= versionsToMake + 1);
        for (uint256 i; i < versionsToMake; ++i) {
            //create vault logic with the right version
            //the first vault version to add is 2, so we add 2 to the index
            account_.setAccountVersion(uint16(i + 2));

            vm.prank(users.creatorAddress);
            factory.setNewAccountInfo(address(mainRegistryExtension), address(account_), Constants.upgradeRoot1To2, "");
        }

        for (uint256 y; y < versionsToBlock.length; ++y) {
            if (versionsToBlock[y] == 0 || versionsToBlock[y] > factory.latestAccountVersion()) {
                continue;
            }
            vm.prank(users.creatorAddress);
            factory.blockAccountVersion(versionsToBlock[y]);
        }

        for (uint256 z; z < versionsToBlock.length; ++z) {
            if (versionsToBlock[z] == 0 || versionsToBlock[z] > factory.latestAccountVersion()) {
                continue;
            }
            vm.expectRevert("FTRY_CV: Account version blocked");
            factory.createAccount(
                uint256(keccak256(abi.encodePacked(versionsToBlock[z], block.timestamp))),
                versionsToBlock[z],
                address(0),
                address(0)
            );
        }
    }

    function testFuzz_Revert_createAccount_Paused(uint256 salt, address sender, address guardian) public {
        // We assume that salt > 0 as we already deployed a Account with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender != address(0));
        vm.assume(guardian != address(0));
        vm.assume(sender != guardian);

        // Given: variables and initialization
        vm.startPrank(users.creatorAddress);
        factory.changeGuardian(guardian);
        vm.stopPrank();
        vm.warp(35 days);

        // When: guardian pauses the contract
        vm.prank(guardian);
        factory.pause();

        // Then: Reverted
        vm.prank(sender);
        vm.expectRevert(FunctionIsPaused.selector);
        factory.createAccount(salt, 0, address(0), address(0));
    }

    function test_isAccount_positive() public {
        address newAccount = factory.createAccount(1, 0, address(0), address(0));

        bool expectedReturn = factory.isAccount(address(newAccount));
        bool actualReturn = true;

        assertEq(expectedReturn, actualReturn);
    }
}
