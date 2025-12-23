/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountV3 } from "../../../src/accounts/AccountV3.sol";
import { AccountVariableVersion } from "../../utils/mocks/accounts/AccountVariableVersion.sol";
import { Constants } from "../../utils/Constants.sol";
import { CreateProxyLib } from "../../../src/libraries/CreateProxyLib.sol";
import { ERC721 } from "../../../lib/solmate/src/tokens/ERC721.sol";
import { Factory } from "../../../src/Factory.sol";
import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";
import { FactoryErrors } from "../../../src/libraries/Errors.sol";
import { GuardianErrors } from "../../../src/libraries/Errors.sol";
import { RevertingProxy } from "../../utils/mocks/proxy/RevertingProxy.sol";
import { Utils } from "../../utils/Utils.sol";

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
    function testFuzz_Revert_createAccount_Paused(uint32 salt, address sender) public {
        // When: guardian pauses the contract
        vm.warp(35 days);
        vm.prank(users.guardian);
        factory.pause();

        // Then: Reverted
        vm.prank(sender);
        vm.expectRevert(GuardianErrors.FunctionIsPaused.selector);
        factory.createAccount(salt, 0, address(0));
    }

    function testFuzz_Revert_createAccount_CreateNonExistingAccountVersion(uint256 accountVersion) public {
        uint256 currentVersion = factory.latestAccountVersion();
        accountVersion = bound(accountVersion, currentVersion + 1, type(uint256).max);

        vm.expectRevert(FactoryErrors.InvalidAccountVersion.selector);
        factory.createAccount(
            uint32(uint256(keccak256(abi.encodePacked(accountVersion, block.timestamp)))), accountVersion, address(0)
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
            //the first account version to add is 4, so we add 4 to the index
            // forge-lint: disable-next-line(unsafe-typecast)
            account_.setAccountVersion(uint16(i + 4));

            vm.prank(users.owner);
            factory.setNewAccountInfo(address(registry), address(account_), Constants.ROOT, "");
        }

        for (uint256 y; y < versionsToBlock.length; ++y) {
            if (versionsToBlock[y] == 0 || versionsToBlock[y] > factory.latestAccountVersion()) {
                continue;
            }
            vm.prank(users.owner);
            factory.blockAccountVersion(versionsToBlock[y]);
        }

        for (uint256 z; z < versionsToBlock.length; ++z) {
            if (versionsToBlock[z] == 0 || versionsToBlock[z] > factory.latestAccountVersion()) {
                continue;
            }
            vm.expectRevert(FactoryErrors.AccountVersionBlocked.selector);
            factory.createAccount(
                uint32(uint256(keccak256(abi.encodePacked(versionsToBlock[z], block.timestamp)))),
                versionsToBlock[z],
                address(0)
            );
        }
    }

    function testFuzz_Revert_createAccount_RevertingProxy(address sender, uint32 salt) public {
        // We assume that salt > 0 as we already deployed an Account with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender != address(0));

        // Get bytecode of Reverting Proxy, need to compile it first.
        new RevertingProxy(address(0));
        bytes memory revertingProxyByteCode = vm.getCode("RevertingProxy.sol");

        // Get bytecode deployed factory.
        bytes memory factoryByteCode = address(factory).code;

        // Override factory bytecode.
        bytes memory proxyByteCode =
            hex"608060405260405161017c38038061017c8339810160408190526100229161008d565b7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc80546001600160a01b0319166001600160a01b0383169081179091556040517fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a2506100ba565b5f6020828403121561009d575f80fd5b81516001600160a01b03811681146100b3575f80fd5b9392505050565b60b6806100c65f395ff3fe608060405236603c57603a7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc5b546001600160a01b03166063565b005b603a7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc602c565b365f80375f80365f845af43d5f803e808015607c573d5ff35b3d5ffdfea2646970667358221220eeb8a2fa918a2057b66e1d3fa3930647dc7a4e56c99898cd9e280beec9d9ba9f64736f6c63430008160033000000000000000000000000";
        factoryByteCode = Utils.veryBadBytesReplacerNoReverts(factoryByteCode, proxyByteCode, revertingProxyByteCode);

        // Etch overridden bytecode of deployed factory.
        vm.etch(address(factory), factoryByteCode);

        vm.broadcast(sender);
        vm.expectRevert(CreateProxyLib.ProxyCreationFailed.selector);
        factory.createAccount(salt, 0, address(0));
    }

    function testFuzz_Revert_createAccount_ContractCollision(address sender, uint32 salt) public {
        // We assume that salt > 0 as we already deployed an Account with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender != address(0));

        vm.broadcast(sender);
        factory.createAccount(salt, 0, address(0));

        vm.broadcast(sender);
        vm.expectRevert(CreateProxyLib.ProxyCreationFailed.selector);
        factory.createAccount(salt, 0, address(0));
    }

    function testFuzz_Success_ExactDeploymentBase() public {
        // Given: The actual sender and user Salt of a Proxy Arcadia Account (id 8199)
        address sender = 0x559458Aac63528fB18893d797FF223dF4D5fa3C9;
        uint32 salt = 1_987_515_790;

        // When: Sender calls createAccount()
        vm.broadcast(sender);
        address proxy = factory.createAccount(salt, 1, address(0));

        // Then: Proxy address matches the actual deployed contract address.
        assertEq(proxy, 0x11331c538eab48dd7aC6Fccf556B76CF8E49Ac26);

        // And: Proxy address matches the calculated contract address.
        assertEq(proxy, factory.getAccountAddress(sender, salt, 1));

        // And: Proxy bytecode matches the actual deployed bytecode.
        assertEq(
            proxy.code,
            hex"608060405236603c57603a7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc5b546001600160a01b03166063565b005b603a7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc602c565b365f80375f80365f845af43d5f803e808015607c573d5ff35b3d5ffdfea2646970667358221220eeb8a2fa918a2057b66e1d3fa3930647dc7a4e56c99898cd9e280beec9d9ba9f64736f6c63430008160033"
        );
    }

    function testFuzz_Success_createAccount_DeployAccountWithNoCreditor(address sender, uint32 salt) public {
        // We assume that salt > 0 as we already deployed an Account with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender != address(0));

        uint256 amountBefore = factory.allAccountsLength();
        address proxy_ = factory.getAccountAddress(sender, salt, 0);

        vm.expectEmit(address(factory));
        emit ERC721.Transfer(address(0), sender, amountBefore + 1);
        vm.expectEmit(address(factory));
        emit Factory.AccountUpgraded(proxy_, 3);

        // Here we create an Account with no specific creditor
        vm.broadcast(sender);
        address actualDeployed = factory.createAccount(salt, 0, address(0));

        // And: Proxy address matches the calculated contract address.
        assertEq(actualDeployed, proxy_);

        assertEq(amountBefore + 1, factory.allAccountsLength());
        assertEq(actualDeployed, factory.allAccounts(factory.allAccountsLength() - 1));
        assertEq(factory.accountIndex(actualDeployed), (factory.allAccountsLength()));
        assertEq(AccountV3(actualDeployed).creditor(), address(0));
        assertEq(AccountV3(actualDeployed).owner(), sender);
    }

    function testFuzz_Success_createAccount_DeployAccountWithCreditor(address sender, uint32 salt) public {
        // We assume that salt > 0 as we already deployed an Account with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender != address(0));

        uint256 amountBefore = factory.allAccountsLength();
        address proxy_ = factory.getAccountAddress(sender, salt, 0);

        vm.expectEmit(address(factory));
        emit ERC721.Transfer(address(0), sender, amountBefore + 1);
        vm.expectEmit(proxy_);
        emit AccountV3.MarginAccountChanged(address(creditorStable1), Constants.LIQUIDATOR);
        vm.expectEmit(address(factory));
        emit Factory.AccountUpgraded(proxy_, 3);

        // Here we create an Account by specifying the creditor address
        vm.broadcast(sender);
        address actualDeployed = factory.createAccount(salt, 0, address(creditorStable1));

        // And: Proxy address matches the calculated contract address.
        assertEq(actualDeployed, proxy_);

        assertEq(amountBefore + 1, factory.allAccountsLength());
        assertEq(actualDeployed, factory.allAccounts(factory.allAccountsLength() - 1));
        assertEq(factory.accountIndex(actualDeployed), (factory.allAccountsLength()));
        assertEq(AccountV3(actualDeployed).creditor(), address(creditorStable1));
    }

    function testFuzz_Success_createAccount_DeployNewProxyWithLogicOwner(uint32 salt, address sender) public {
        // We assume that salt > 0 as we already deployed an Account with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender != address(0));

        uint256 amountBefore = factory.allAccountsLength();

        vm.broadcast(sender);
        address actualDeployed = factory.createAccount(salt, 0, address(0));

        // And: Proxy address matches the calculated contract address.
        assertEq(actualDeployed, factory.getAccountAddress(sender, salt, 0));

        assertEq(amountBefore + 1, factory.allAccountsLength());
        assertEq(AccountV3(actualDeployed).owner(), sender);
    }

    function testFuzz_Success_createAccount_CreationCannotBeFrontRanWithIdenticalSalt(
        uint32 salt,
        address sender0,
        address sender1
    ) public {
        // We assume that salt > 0 as we already deployed an Account with all inputs to 0
        vm.assume(salt > 0);
        // forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(uint32(uint160(sender0)) != uint32(uint160(sender1)));
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
