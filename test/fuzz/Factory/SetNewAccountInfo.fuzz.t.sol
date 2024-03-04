/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Factory_Fuzz_Test, FactoryErrors } from "./_Factory.fuzz.t.sol";

import { AccountV2 } from "../../utils/mocks/accounts/AccountV2.sol";
import { AccountVariableVersion } from "../../utils/mocks/accounts/AccountVariableVersion.sol";
import { Constants } from "../../utils/Constants.sol";
import { Factory } from "../../../src/Factory.sol";
import { Registry, RegistryExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "setNewAccountInfo" of contract "Factory".
 */
contract SetNewAccountInfo_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountVariableVersion internal accountVarVersion;
    RegistryExtension internal registry2;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();

        accountVarVersion = new AccountVariableVersion(1, address(factory));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setNewAccountInfo_NonOwner(address unprivilegedAddress_, address logic) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.assume(logic != address(registryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        factory.setNewAccountInfo(address(registryExtension), logic, Constants.upgradeRoot1To2, "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_VersionRootIsZero(address registry_, address logic) public {
        vm.assume(logic != address(registryExtension));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(FactoryErrors.VersionRootIsZero.selector);
        factory.setNewAccountInfo(registry_, logic, bytes32(0), "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_LogicAddressIsZero(address registry_, bytes32 versionRoot) public {
        vm.assume(versionRoot != bytes32(0));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(FactoryErrors.ImplIsZero.selector);
        factory.setNewAccountInfo(registry_, address(0), versionRoot, "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_InvalidAccountContract(address newAssetAddress, address logic) public {
        vm.assume(logic > address(10));
        vm.assume(logic != address(factory));
        vm.assume(logic != address(registryExtension));
        vm.assume(logic != address(vm));
        vm.assume(logic != address(accountV1Logic));
        vm.assume(logic != address(accountV2Logic));
        vm.assume(logic != address(proxyAccount));
        vm.assume(logic != address(sequencerUptimeOracle));
        vm.assume(logic != address(accountVarVersion));
        vm.assume(newAssetAddress != address(0));

        vm.startPrank(users.creatorAddress);
        registry2 = new RegistryExtension(address(factory), address(sequencerUptimeOracle));
        vm.expectRevert(bytes(""));
        factory.setNewAccountInfo(address(registry2), logic, Constants.upgradeProof1To2, "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_InvalidAccountVersion() public {
        AccountV2 newAccountV2 = new AccountV2(address(factory));
        AccountV2 newAccountV2_2 = new AccountV2(address(factory));

        vm.startPrank(users.creatorAddress);
        //first set an actual version 2
        factory.setNewAccountInfo(address(registryExtension), address(newAccountV2), Constants.upgradeRoot1To2, "");
        //then try to register another account logic address which has version 2 in its bytecode
        vm.expectRevert(FactoryErrors.VersionMismatch.selector);
        factory.setNewAccountInfo(address(registryExtension), address(newAccountV2_2), Constants.upgradeRoot1To2, "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_InvalidAccountFactory(address nonFactory) public {
        vm.assume(nonFactory != address(factory));

        AccountV2 badAccount = new AccountV2(nonFactory);

        vm.prank(users.creatorAddress);
        vm.expectRevert(FactoryErrors.FactoryMismatch.selector);
        factory.setNewAccountInfo(address(registryExtension), address(badAccount), Constants.upgradeRoot1To2, "");
    }

    function testFuzz_Revert_setNewAccountInfo_InvalidRegistryFactory(address nonFactory) public {
        vm.assume(nonFactory != address(factory));

        AccountV2 account_ = new AccountV2(nonFactory);
        Registry badRegistry = new Registry(nonFactory, address(sequencerUptimeOracle));

        vm.prank(users.creatorAddress);
        vm.expectRevert(FactoryErrors.FactoryMismatch.selector);
        factory.setNewAccountInfo(address(badRegistry), address(account_), Constants.upgradeRoot1To2, "");
    }

    function testFuzz_Success_setNewAccountInfo(address logic, bytes calldata data) public {
        vm.assume(logic > address(10));
        vm.assume(logic != address(factory));
        vm.assume(logic != address(registryExtension));
        vm.assume(logic != address(vm));
        vm.assume(logic != address(accountV1Logic));
        vm.assume(logic != address(accountV2Logic));
        vm.assume(logic != address(proxyAccount));
        vm.assume(logic != address(sequencerUptimeOracle));
        vm.assume(logic != address(accountVarVersion));

        uint256 latestAccountVersionPre = factory.latestAccountVersion();
        bytes memory code = address(accountVarVersion).code;
        vm.etch(logic, code);
        AccountVariableVersion(logic).setAccountVersion(latestAccountVersionPre + 1);
        AccountVariableVersion(logic).setFactory(address(factory));

        vm.prank(users.creatorAddress);
        registry2 = new RegistryExtension(address(factory), address(sequencerUptimeOracle));
        vm.assume(logic != address(registry2));

        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit AccountVersionAdded(uint16(latestAccountVersionPre + 1), address(registry2), logic);
        factory.setNewAccountInfo(address(registry2), logic, Constants.upgradeRoot1To2, data);
        vm.stopPrank();

        assertEq(factory.versionRoot(), Constants.upgradeRoot1To2);
        (address registry_, address addresslogic_, bytes memory data_) =
            factory.versionInformation(latestAccountVersionPre + 1);
        assertEq(registry_, address(registry2));
        assertEq(addresslogic_, logic);
        assertEq(data_, data);
        assertEq(factory.latestAccountVersion(), latestAccountVersionPre + 1);
    }
}
