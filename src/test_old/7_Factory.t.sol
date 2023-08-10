/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaAccountsFixture.f.sol";

contract FactoryTest is DeployArcadiaAccounts {
    using stdStorage for StdStorage;

    MainRegistry internal mainRegistry2;

    //events
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event AccountUpgraded(address indexed accountAddress, uint16 oldVersion, uint16 indexed newVersion);
    event AccountVersionAdded(
        uint16 indexed version, address indexed registry, address indexed logic, bytes32 versionRoot
    );
    event AccountVersionBlocked(uint16 version);

    error FunctionIsPaused();

    //this is a before
    constructor() DeployArcadiaAccounts() { }

    //this is a before each
    function setUp() public {
        vm.startPrank(creatorAddress);
        factory = new FactoryExtension();
        mainRegistry = new mainRegistryExtension(address(factory));
        factory.setNewAccountInfo(address(mainRegistry), address(account), Constants.upgradeRoot1To2, "");
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          CONTRACT OWNERSHIP
    /////////////////////////////////////////////////////////////// */

    function testSuccess_transferOwnership(address owner, address to) public {
        vm.assume(to != address(0));

        vm.prank(owner);
        Factory factoryContr_m = new FactoryExtension();
        assertEq(owner, factoryContr_m.owner());

        vm.prank(owner);
        factoryContr_m.transferOwnership(to);
        assertEq(to, factoryContr_m.owner());
    }

    function testRevert_transferOwnership_NonOwner(address owner, address to, address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != owner);

        vm.prank(owner);
        Factory factoryContr_m = new FactoryExtension();
        assertEq(owner, factoryContr_m.owner());

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        factoryContr_m.transferOwnership(to);
        vm.stopPrank();

        assertEq(owner, factoryContr_m.owner());
    }

    /* ///////////////////////////////////////////////////////////////
                          ACCOUNT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    // Test migrated to new test
    /*     function testSuccess_createAccount_DeployAccountContractMappings(uint256 salt) public {
    } */

    // Test migrated to new test suite
    /*     function testSuccess_createAccount_DeployNewProxyWithLogic(uint256 salt) public {
    } */

    // Test migrated to new test suite
    /*     function testSuccess_createAccount_DeployNewProxyWithLogicOwner(uint256 salt, address sender) public {
    } */

    // Test migrated to new test suite
    /*     function testSuccess_createAccount_CreationCannotBeFrontRunnedWithIdenticalSalt(
        uint256 salt,
        address sender0,
        address sender1
    ) public {} */

    // Test migrated to new test suite
    /*     function testRevert_createAccount_CreateNonExistingAccountVersion(uint16 accountVersion) public {} */

    // Test migrated to new test suite
    /*     function testRevert_createAccount_FromBlockedVersion(
        uint16 accountVersion,
        uint16 versionsToMake,
        uint16[] calldata versionsToBlock
    ) public {} */

    // Test migrated to new test suite
    /*     function testRevert_createAccount_Paused(uint256 salt, address sender, address guardian) public {} */

    // Test migrated to new test suite
    /*     function testSuccess_isAccount_positive() public {} */

    function testSuccess_isAccount_negative(address random) public {
        bool expectedReturn = factory.isAccount(random);
        bool actualReturn = false;

        assertEq(expectedReturn, actualReturn);
    }

    function testSuccess_ownerOfAccount_NonAccount(address nonAccount) public {
        assertEq(factory.ownerOfAccount(nonAccount), address(0));
    }

    /* ///////////////////////////////////////////////////////////////
                    ACCOUNT VERSION MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testRevert_setNewAccountInfo_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        factory.setNewAccountInfo(address(mainRegistry), address(proxyAddr), Constants.upgradeRoot1To2, "");
        vm.stopPrank();
    }

    function testRevert_setNewAccountInfo_VersionRootIsZero(address mainRegistry_, address logic) public {
        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_SNVI: version root is zero");
        factory.setNewAccountInfo(mainRegistry_, logic, bytes32(0), "");
        vm.stopPrank();
    }

    function testRevert_setNewAccountInfo_LogicAddressIsZero(address mainRegistry_, bytes32 versionRoot) public {
        vm.assume(versionRoot != bytes32(0));

        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_SNVI: logic address is zero");
        factory.setNewAccountInfo(mainRegistry_, address(0), versionRoot, "");
        vm.stopPrank();
    }

    function testRevert_setNewAccountInfo_OwnerSetsNewAccountWithInfoMissingBaseCurrencyInMainRegistry(
        address newAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        vm.assume(newAssetAddress != address(0));

        vm.startPrank(creatorAddress);
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );

        mainRegistry2 = new mainRegistryExtension(address(factory));
        vm.expectRevert("FTRY_SNVI: counter mismatch");
        factory.setNewAccountInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, "");
        vm.stopPrank();
    }

    function testRevert_setNewAccountInfo_OwnerSetsNewAccountInfoWithDifferentBaseCurrencyInMainRegistry(
        address randomAssetAddress,
        address logic
    ) public {
        vm.assume(logic != address(0));
        vm.assume(randomAssetAddress != address(0));
        vm.assume(randomAssetAddress != address(eth));

        vm.startPrank(creatorAddress);
        //Add eth as second basecurrency
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );

        mainRegistry2 = new mainRegistryExtension(address(factory));
        //Add randomAssetAddress as second basecurrency
        mainRegistry2.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: randomAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "RANDOM",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );
        vm.expectRevert("FTRY_SNVI: no baseCurrency match");
        factory.setNewAccountInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, "");
        vm.stopPrank();
    }

    function testSuccess_setNewAccountInfo(address mainRegistry_, address logic, bytes calldata data) public {
        vm.assume(logic != address(0));

        vm.prank(creatorAddress);
        factory = new FactoryExtension();
        assertTrue(factory.getAccountVersionRoot() == bytes32(0));

        uint256 latestAccountVersionPre = factory.latestAccountVersion();

        vm.startPrank(creatorAddress);
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

    function testSuccess_setNewAccountInfo_OwnerSetsNewAccountWithIdenticalBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic,
        bytes calldata data
    ) public {
        vm.assume(logic != address(0));
        vm.assume(newAssetAddress != address(0));

        uint256 latestAccountVersionPre = factory.latestAccountVersion();

        vm.startPrank(creatorAddress);
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );

        mainRegistry2 = new mainRegistryExtension(address(factory));
        mainRegistry2.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );
        factory.setNewAccountInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, data);
        vm.stopPrank();

        assertEq(factory.latestAccountVersion(), ++latestAccountVersionPre);
    }

    function testSuccess_setNewAccountInfo_OwnerSetsNewAccountWithMoreBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic,
        bytes calldata data
    ) public {
        vm.assume(logic != address(0));
        vm.assume(newAssetAddress != address(0));

        uint256 latestAccountVersionPre = factory.latestAccountVersion();

        vm.startPrank(creatorAddress);
        mainRegistry2 = new mainRegistryExtension(address(factory));
        mainRegistry2.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: newAssetAddress,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );
        factory.setNewAccountInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, data);
        vm.stopPrank();

        assertEq(factory.latestAccountVersion(), ++latestAccountVersionPre);
    }

    function testRevert_blockAccountVersion_NonOwner(uint16 accountVersion, address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        uint256 currentVersion = factory.latestAccountVersion();
        vm.assume(accountVersion <= currentVersion);
        vm.assume(accountVersion != 0);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        factory.blockAccountVersion(accountVersion);
        vm.stopPrank();
    }

    function testRevert_blockAccountVersion_BlockNonExistingAccountVersion(uint16 accountVersion) public {
        uint256 currentVersion = factory.latestAccountVersion();
        vm.assume(accountVersion > currentVersion || accountVersion == 0);

        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_BVV: Invalid version");
        factory.blockAccountVersion(accountVersion);
        vm.stopPrank();
    }

    function testSuccess_blockAccountVersion(uint16 accountVersion) public {
        uint256 currentVersion = factory.latestAccountVersion();
        vm.assume(accountVersion <= currentVersion);
        vm.assume(accountVersion != 0);

        vm.startPrank(creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit AccountVersionBlocked(accountVersion);
        factory.blockAccountVersion(accountVersion);
        vm.stopPrank();

        assertTrue(factory.accountVersionBlocked(accountVersion));
    }

    /* ///////////////////////////////////////////////////////////////
                    ACCOUNT LIQUIDATION LOGIC
    /////////////////////////////////////////////////////////////// */

    function testRevert_liquidate_NonAccount(address liquidator_, address nonAccount) public {
        vm.startPrank(nonAccount);
        vm.expectRevert("FTRY: Not a Account");
        factory.liquidate(liquidator_);
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function testSuccess_allAccountsLength_AccountIdStartFromZero() public {
        assertEq(factory.allAccountsLength(), 0);
    }

    /* ///////////////////////////////////////////////////////////////
                        ERC-721 LOGIC
    /////////////////////////////////////////////////////////////// */

    function testSuccess_setBaseURI(string calldata uri) public {
        vm.prank(creatorAddress);
        factory.setBaseURI(uri);

        string memory expectedUri = factory.baseURI();

        assertEq(expectedUri, uri);
    }

    function testRevert_setBaseURI_NonOwner(string calldata uri, address unprivilegedAddress_) public {
        vm.assume(address(unprivilegedAddress_) != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        factory.setBaseURI(uri);
        vm.stopPrank();
    }
}
