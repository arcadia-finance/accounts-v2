/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

import { AccountV2 } from "../.././utils/mocks/AccountV2.sol";
import { AccountVariableVersion } from "../.././utils/mocks/AccountVariableVersion.sol";
import { Factory } from "../../../src/Factory.sol";
import { MainRegistry_New, MainRegistryExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "setNewAccountInfo" of contract "Factory".
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

    /* ///////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function addBaseCurrenciesToMainRegistry2() internal {
        // Add STABLE1 AND TOKEN1 as baseCurrencies in MainRegistry2
        vm.startPrank(mainRegistry2.owner());
        mainRegistry2.addBaseCurrency(
            MainRegistry_New.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable1),
                baseCurrencyToUsdOracle: address(mockOracles.stable1ToUsd),
                baseCurrencyLabel: "STABLE1",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.stableDecimals))
            })
        );

        mainRegistry2.addBaseCurrency(
            MainRegistry_New.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                assetAddress: address(mockERC20.token1),
                baseCurrencyToUsdOracle: address(mockOracles.token1ToUsd),
                baseCurrencyLabel: "TOKEN1",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );
        vm.stopPrank();
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

    function testFuzz_Revert_setNewAccountInfo_OwnerSetsNewAccountWithInfoMissingBaseCurrencyInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        vm.assume(logic != address(mainRegistryExtension));
        vm.assume(newAssetAddress != address(0));

        vm.startPrank(users.creatorAddress);
        mainRegistry2 = new MainRegistryExtension(address(factory));
        vm.expectRevert("FTRY_SNVI: counter mismatch");
        factory.setNewAccountInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, "");
        vm.stopPrank();
    }

    function testFuzz_Revert_setNewAccountInfo_OwnerSetsNewAccountInfoWithDifferentBaseCurrencyInMainRegistry(
        address randomAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        vm.assume(logic != address(mainRegistryExtension));
        vm.assume(randomAssetAddress != address(0));
        vm.assume(randomAssetAddress != address(mockERC20.stable1));
        vm.assume(randomAssetAddress != address(mockERC20.token1));

        vm.startPrank(users.creatorAddress);
        mainRegistry2 = new MainRegistryExtension(address(factory));
        //Add randomAssetAddress as second basecurrency
        mainRegistry2.addBaseCurrency(
            MainRegistry_New.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: randomAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "RANDOM",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );
        mainRegistry2.addBaseCurrency(
            MainRegistry_New.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                assetAddress: address(mockERC20.token1),
                baseCurrencyToUsdOracle: address(mockOracles.token1ToUsd),
                baseCurrencyLabel: "TOKEN1",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );
        vm.stopPrank();

        vm.prank(users.creatorAddress);
        vm.expectRevert("FTRY_SNVI: no baseCurrency match");
        factory.setNewAccountInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, "");
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

    function testFuzz_Success_setNewAccountInfo_NoBaseCurrenciesSetInMainRegistry(
        address mainRegistry_,
        address logic,
        bytes calldata data
    ) public {
        vm.assume(logic > address(10));
        vm.assume(logic != address(vm));
        vm.assume(logic != address(mainRegistryExtension));

        // Redeploy Factory to start with a different MainRegistry without BaseCurrencies.
        vm.prank(users.creatorAddress);
        factory = new Factory();
        assertTrue(factory.getAccountVersionRoot() == bytes32(0));

        uint256 latestAccountVersionPre = factory.latestAccountVersion();
        bytes memory code = address(accountVarVersion).code;
        vm.etch(logic, code);
        AccountVariableVersion(logic).setAccountVersion(latestAccountVersionPre + 1);

        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit AccountVersionAdded(uint16(latestAccountVersionPre + 1), mainRegistry_, logic, Constants.upgradeRoot1To2);
        factory.setNewAccountInfo(mainRegistry_, logic, Constants.upgradeRoot1To2, data);
        vm.stopPrank();

        (address registry_, address addresslogic_, bytes32 root, bytes memory data_) =
            factory.accountDetails(latestAccountVersionPre + 1);
        assertEq(registry_, mainRegistry_);
        assertEq(addresslogic_, logic);
        assertEq(root, Constants.upgradeRoot1To2);
        assertEq(data_, data);
        assertEq(factory.latestAccountVersion(), latestAccountVersionPre + 1);
    }

    function testFuzz_Success_setNewAccountInfo_OwnerSetsNewAccountWithIdenticalBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic,
        bytes calldata data
    ) public {
        vm.assume(logic > address(10));
        vm.assume(logic != address(factory));
        vm.assume(logic != address(vm));
        vm.assume(logic != address(mainRegistryExtension));
        vm.assume(newAssetAddress != address(0));

        uint256 latestAccountVersionPre = factory.latestAccountVersion();
        bytes memory code = address(accountVarVersion).code;
        vm.etch(logic, code);
        AccountVariableVersion(logic).setAccountVersion(latestAccountVersionPre + 1);

        vm.prank(users.creatorAddress);
        mainRegistry2 = new MainRegistryExtension(address(factory));
        addBaseCurrenciesToMainRegistry2();

        vm.prank(users.creatorAddress);
        factory.setNewAccountInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, data);

        assertEq(factory.latestAccountVersion(), ++latestAccountVersionPre);
    }

    function testFuzz_Success_setNewAccountInfo_OwnerSetsNewAccountWithMoreBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic,
        bytes calldata data
    ) public {
        vm.assume(logic > address(10));
        vm.assume(logic != address(factory));
        vm.assume(logic != address(mainRegistryExtension));
        vm.assume(logic != address(vm));
        vm.assume(newAssetAddress != address(0));

        uint256 latestAccountVersionPre = factory.latestAccountVersion();
        bytes memory code = address(accountVarVersion).code;
        vm.etch(logic, code);
        AccountVariableVersion(logic).setAccountVersion(latestAccountVersionPre + 1);

        vm.prank(users.creatorAddress);
        mainRegistry2 = new MainRegistryExtension(address(factory));
        addBaseCurrenciesToMainRegistry2();

        // Add a 4th base currency to mainRegistry2 that is not in mainRegistry
        vm.prank(users.creatorAddress);
        mainRegistry2.addBaseCurrency(
            MainRegistry_New.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable2),
                baseCurrencyToUsdOracle: address(mockOracles.stable2ToUsd),
                baseCurrencyLabel: "STABLE2",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.stableDecimals))
            })
        );

        vm.prank(users.creatorAddress);
        factory.setNewAccountInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, data);

        assertEq(factory.latestAccountVersion(), ++latestAccountVersionPre);
    }
}
