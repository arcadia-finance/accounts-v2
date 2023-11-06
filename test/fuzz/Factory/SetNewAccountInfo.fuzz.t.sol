/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

import { AccountV2 } from "../../utils/mocks/AccountV2.sol";
import { AccountVariableVersion } from "../../utils/mocks/AccountVariableVersion.sol";
import { Constants } from "../../utils/Constants.sol";
import { Factory } from "../../../src/Factory.sol";
import { MainRegistry, MainRegistryExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "setNewAccountInfo" of contract "Factory".
 */
contract SetNewAccountInfo_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountVariableVersion internal accountVarVersion;
    MainRegistryExtension internal mainRegistry2;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();

        accountVarVersion = new AccountVariableVersion(1);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setNewAccountInfo_NonOwner(address unprivilegedAddress_, address logic) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.assume(logic != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        factory.setNewAccountInfo(address(mainRegistryExtension), logic, Constants.upgradeRoot1To2, "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_VersionRootIsZero(address mainRegistry_, address logic) public {
        vm.assume(logic != address(mainRegistryExtension));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("FTRY_SNVI: version root is zero");
        factory.setNewAccountInfo(mainRegistry_, logic, bytes32(0), "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_LogicAddressIsZero(address mainRegistry_, bytes32 versionRoot) public {
        vm.assume(versionRoot != bytes32(0));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("FTRY_SNVI: logic address is zero");
        factory.setNewAccountInfo(mainRegistry_, address(0), versionRoot, "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_InvalidAccountContract(address newAssetAddress, address logic) public {
        vm.assume(logic != address(0));
        vm.assume(logic != address(mainRegistryExtension));
        vm.assume(newAssetAddress != address(0));

        vm.startPrank(users.creatorAddress);
        mainRegistry2 = new MainRegistryExtension(address(factory));
        vm.expectRevert(bytes(""));
        factory.setNewAccountInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_InvalidAccountVersion() public {
        AccountV2 newAccountV2 = new AccountV2();
        AccountV2 newAccountV2_2 = new AccountV2();

        vm.startPrank(users.creatorAddress);
        //first set an actual version 2
        factory.setNewAccountInfo(address(mainRegistryExtension), address(newAccountV2), Constants.upgradeRoot1To2, "");
        //then try to register another vault logic address which has version 2 in its bytecode
        vm.expectRevert("FTRY_SNVI: vault version mismatch");
        factory.setNewAccountInfo(
            address(mainRegistryExtension), address(newAccountV2_2), Constants.upgradeRoot1To2, ""
        );
        vm.stopPrank();
    }

    function testFuzz_Success_setNewAccountInfo(address logic, bytes calldata data) public {
        vm.assume(logic > address(10));
        vm.assume(logic != address(factory));
        vm.assume(logic != address(vm));
        vm.assume(logic != address(mainRegistryExtension));

        uint256 latestAccountVersionPre = factory.latestAccountVersion();
        bytes memory code = address(accountVarVersion).code;
        vm.etch(logic, code);
        AccountVariableVersion(logic).setAccountVersion(latestAccountVersionPre + 1);

        vm.prank(users.creatorAddress);
        mainRegistry2 = new MainRegistryExtension(address(factory));

        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit AccountVersionAdded(
            uint16(latestAccountVersionPre + 1), address(mainRegistry2), logic, Constants.upgradeRoot1To2
        );
        factory.setNewAccountInfo(address(mainRegistry2), logic, Constants.upgradeRoot1To2, data);
        vm.stopPrank();

        (address registry_, address addresslogic_, bytes32 root, bytes memory data_) =
            factory.accountDetails(latestAccountVersionPre + 1);
        assertEq(registry_, address(mainRegistry2));
        assertEq(addresslogic_, logic);
        assertEq(root, Constants.upgradeRoot1To2);
        assertEq(data_, data);
        assertEq(factory.latestAccountVersion(), latestAccountVersionPre + 1);
    }
}
