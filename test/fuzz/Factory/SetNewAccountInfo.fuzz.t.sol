/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountLogicMock } from "../../utils/mocks/accounts/AccountLogicMock.sol";
import { AccountVariableVersion } from "../../utils/mocks/accounts/AccountVariableVersion.sol";
import { Constants } from "../../utils/Constants.sol";
import { Factory } from "../../../src/Factory.sol";
import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";
import { FactoryErrors } from "../../../src/libraries/Errors.sol";
import { RegistryL2, RegistryL2Extension } from "../../utils/extensions/RegistryL2Extension.sol";

/**
 * @notice Fuzz tests for the function "setNewAccountInfo" of contract "Factory".
 */
contract SetNewAccountInfo_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountVariableVersion internal accountVarVersion;
    RegistryL2Extension internal registry2;

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
        vm.assume(unprivilegedAddress_ != users.owner);
        vm.assume(logic != address(registry));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        factory.setNewAccountInfo(address(registry), logic, Constants.upgradeRoot3To4And4To3, "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_VersionRootIsZero(address registry_, address logic) public {
        vm.assume(logic != address(registry));

        vm.startPrank(users.owner);
        vm.expectRevert(FactoryErrors.VersionRootIsZero.selector);
        factory.setNewAccountInfo(registry_, logic, bytes32(0), "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_LogicAddressIsZero(address registry_, bytes32 versionRoot) public {
        vm.assume(versionRoot != bytes32(0));

        vm.startPrank(users.owner);
        vm.expectRevert(FactoryErrors.ImplIsZero.selector);
        factory.setNewAccountInfo(registry_, address(0), versionRoot, "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_InvalidAccountContract(address newAssetAddress, address logic) public {
        vm.assume(logic != address(factory));
        vm.assume(logic != address(registry));
        vm.assume(logic != address(vm));
        vm.assume(logic != address(accountLogic));
        vm.assume(logic != address(account));
        vm.assume(logic != address(sequencerUptimeOracle));
        vm.assume(logic != address(accountVarVersion));
        vm.assume(newAssetAddress != address(0));

        vm.startPrank(users.owner);
        registry2 = new RegistryL2Extension(address(factory), address(sequencerUptimeOracle));
        vm.assume(logic.code.length > 0);
        if (logic.code.length == 0 && !isPrecompile(logic)) {
            vm.expectRevert(abi.encodePacked("call to non-contract address ", vm.toString(logic)));
        } else {
            vm.expectRevert(bytes(""));
        }
        factory.setNewAccountInfo(address(registry2), logic, Constants.upgradeRoot3To4And4To3, "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_InvalidAccountVersion() public {
        AccountLogicMock newAccountLogicMock = new AccountLogicMock(address(factory));
        AccountLogicMock newAccountLogicMock_2 = new AccountLogicMock(address(factory));

        vm.startPrank(users.owner);
        //first set an actual version 2
        factory.setNewAccountInfo(address(registry), address(newAccountLogicMock), Constants.upgradeRoot3To4And4To3, "");
        //then try to register another account logic address which has version 2 in its bytecode
        vm.expectRevert(FactoryErrors.VersionMismatch.selector);
        factory.setNewAccountInfo(
            address(registry), address(newAccountLogicMock_2), Constants.upgradeRoot3To4And4To3, ""
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_InvalidAccountFactory(address nonFactory) public {
        vm.assume(nonFactory != address(factory));

        AccountLogicMock badAccount = new AccountLogicMock(nonFactory);

        vm.prank(users.owner);
        vm.expectRevert(FactoryErrors.FactoryMismatch.selector);
        factory.setNewAccountInfo(address(registry), address(badAccount), Constants.upgradeRoot3To4And4To3, "");
    }

    function testFuzz_Revert_setNewAccountInfo_InvalidRegistryFactory(address nonFactory) public {
        vm.assume(nonFactory != address(factory));

        AccountLogicMock account_ = new AccountLogicMock(nonFactory);
        RegistryL2 badRegistry = new RegistryL2(nonFactory, address(sequencerUptimeOracle));

        vm.prank(users.owner);
        vm.expectRevert(FactoryErrors.FactoryMismatch.selector);
        factory.setNewAccountInfo(address(badRegistry), address(account_), Constants.upgradeRoot3To4And4To3, "");
    }

    function testFuzz_Success_setNewAccountInfo(address logic, bytes calldata data) public {
        vm.assume(!isPrecompile(logic));
        vm.assume(logic != address(factory));
        vm.assume(logic != address(registry));
        vm.assume(logic != address(vm));
        vm.assume(logic != address(accountLogic));
        vm.assume(logic != address(account));
        vm.assume(logic != address(sequencerUptimeOracle));
        vm.assume(logic != address(accountVarVersion));

        uint256 latestAccountVersionPre = factory.latestAccountVersion();
        bytes memory code = address(accountVarVersion).code;
        vm.etch(logic, code);
        AccountVariableVersion(logic).setAccountVersion(latestAccountVersionPre + 1);
        AccountVariableVersion(logic).setFactory(address(factory));

        vm.prank(users.owner);
        registry2 = new RegistryL2Extension(address(factory), address(sequencerUptimeOracle));
        vm.assume(logic != address(registry2));

        vm.startPrank(users.owner);
        vm.expectEmit(true, true, true, true);
        emit Factory.AccountVersionAdded(uint16(latestAccountVersionPre + 1), address(registry2), logic);
        factory.setNewAccountInfo(address(registry2), logic, Constants.upgradeRoot3To4And4To3, data);
        vm.stopPrank();

        assertEq(factory.versionRoot(), Constants.upgradeRoot3To4And4To3);
        (address registry_, address addresslogic_, bytes memory data_) =
            factory.versionInformation(latestAccountVersionPre + 1);
        assertEq(registry_, address(registry2));
        assertEq(addresslogic_, logic);
        assertEq(data_, data);
        assertEq(factory.latestAccountVersion(), latestAccountVersionPre + 1);
    }
}
