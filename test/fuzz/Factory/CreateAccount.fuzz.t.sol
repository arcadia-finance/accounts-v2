/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Factory_Fuzz_Test, FactoryErrors } from "./_Factory.fuzz.t.sol";

import { AccountV1 } from "../../../src/accounts/AccountV1.sol";
import { AccountVariableVersion } from "../../utils/mocks/accounts/AccountVariableVersion.sol";
import { Constants } from "../../utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "createAccount" of contract "Factory".
 */
contract CreateAccount_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_createAccount_Paused(uint256 salt, address sender) public {
        // When: guardian pauses the contract
        vm.warp(35 days);
        vm.prank(users.guardian);
        factory.pause();

        // Then: Reverted
        vm.prank(sender);
        vm.expectRevert(FunctionIsPaused.selector);
        factory.createAccount(salt, 0, address(0));
    }

    function testFuzz_Revert_createAccount_CreateNonExistingAccountVersion(uint256 accountVersion) public {
        uint256 currentVersion = factory.latestAccountVersion();
        accountVersion = bound(accountVersion, currentVersion + 1, type(uint256).max);

        vm.expectRevert(FactoryErrors.InvalidAccountVersion.selector);
        factory.createAccount(
            uint256(keccak256(abi.encodePacked(accountVersion, block.timestamp))), accountVersion, address(0)
        );
    }

    function testFuzz_Revert_createAccount_FromBlockedVersion(
        uint8 accountVersion,
        uint8 versionsToMake,
        uint8[] calldata versionsToBlock
    ) public {
        AccountVariableVersion account_ = new AccountVariableVersion(0, address(factory));

        vm.assume(versionsToBlock.length < 10 && versionsToBlock.length > 0);
        vm.assume(uint256(versionsToMake) + 1 < type(uint8).max);
        vm.assume(accountVersion <= versionsToMake + 1);
        for (uint256 i; i < versionsToMake; ++i) {
            //create account logic with the right version
            //the first account version to add is 2, so we add 2 to the index
            account_.setAccountVersion(uint16(i + 2));

            vm.prank(users.creatorAddress);
            factory.setNewAccountInfo(address(registryExtension), address(account_), Constants.upgradeRoot1To2, "");
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
            vm.expectRevert(FactoryErrors.AccountVersionBlocked.selector);
            factory.createAccount(
                uint256(keccak256(abi.encodePacked(versionsToBlock[z], block.timestamp))),
                versionsToBlock[z],
                address(0)
            );
        }
    }

    function testFuzz_Success_createAccount_DeployAccountWithNoCreditor(uint256 salt) public {
        // We assume that salt > 0 as we already deployed an Account with all inputs to 0
        vm.assume(salt > 0);
        uint256 amountBefore = factory.allAccountsLength();

        vm.expectEmit();
        emit Transfer(address(0), address(this), amountBefore + 1);
        vm.expectEmit(false, true, true, true);
        emit AccountUpgraded(address(0), 1);

        // Here we create an Account with no specific creditor
        address actualDeployed = factory.createAccount(salt, 0, address(0));

        assertEq(amountBefore + 1, factory.allAccountsLength());
        assertEq(actualDeployed, factory.allAccounts(factory.allAccountsLength() - 1));
        assertEq(factory.accountIndex(actualDeployed), (factory.allAccountsLength()));
        assertEq(AccountV1(actualDeployed).creditor(), address(0));
        assertEq(AccountV1(actualDeployed).owner(), address(this));
    }

    function testFuzz_Success_createAccount_DeployAccountWithCreditor(uint256 salt) public {
        // We assume that salt > 0 as we already deployed an Account with all inputs to 0
        vm.assume(salt > 0);
        uint256 amountBefore = factory.allAccountsLength();

        vm.expectEmit();
        emit Transfer(address(0), address(this), amountBefore + 1);
        vm.expectEmit();
        emit MarginAccountChanged(address(creditorStable1), Constants.initLiquidator);
        vm.expectEmit(false, true, true, true);
        emit AccountUpgraded(address(0), 1);

        // Here we create an Account by specifying the creditor address
        address actualDeployed = factory.createAccount(salt, 0, address(creditorStable1));

        assertEq(amountBefore + 1, factory.allAccountsLength());
        assertEq(actualDeployed, factory.allAccounts(factory.allAccountsLength() - 1));
        assertEq(factory.accountIndex(actualDeployed), (factory.allAccountsLength()));
        assertEq(AccountV1(actualDeployed).creditor(), address(creditorStable1));
    }

    function testFuzz_Success_createAccount_DeployNewProxyWithLogicOwner(uint256 salt, address sender) public {
        // We assume that salt > 0 as we already deployed an Account with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender != address(0));
        uint256 amountBefore = factory.allAccountsLength();
        vm.prank(sender);
        address actualDeployed = factory.createAccount(salt, 0, address(0));
        assertEq(amountBefore + 1, factory.allAccountsLength());
        assertEq(AccountV1(actualDeployed).owner(), address(sender));
    }

    function testFuzz_Success_createAccount_CreationCannotBeFrontRunnedWithIdenticalSalt(
        uint256 salt,
        address sender0,
        address sender1
    ) public {
        // We assume that salt > 0 as we already deployed an Account with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender0 != sender1);
        vm.assume(sender0 != address(0));
        vm.assume(sender1 != address(0));

        //Broadcast changes the tx.origin, prank only changes the msg.sender, not tx.origin
        vm.broadcast(sender0);
        address proxy0 = factory.createAccount(salt, 0, address(0));

        vm.broadcast(sender1);
        address proxy1 = factory.createAccount(salt, 0, address(0));

        assertTrue(proxy0 != proxy1);
    }
}
