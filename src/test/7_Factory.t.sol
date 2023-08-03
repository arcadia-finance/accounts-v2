/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

contract FactoryTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    MainRegistry internal mainRegistry2;

    //events
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event VaultUpgraded(address indexed vaultAddress, uint16 oldVersion, uint16 indexed newVersion);
    event VaultVersionAdded(
        uint16 indexed version, address indexed registry, address indexed logic, bytes32 versionRoot
    );
    event VaultVersionBlocked(uint16 version);

    error FunctionIsPaused();

    //this is a before
    constructor() DeployArcadiaVaults() { }

    //this is a before each
    function setUp() public {
        vm.startPrank(creatorAddress);
        factory = new FactoryExtension();
        mainRegistry = new mainRegistryExtension(address(factory));
        liquidator = new Liquidator(address(factory));

        factory.setNewVaultInfo(address(mainRegistry), address(vault), Constants.upgradeRoot1To2, "");
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
                          VAULT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testSuccess_isVault_negative(address random) public {
        bool expectedReturn = factory.isVault(random);
        bool actualReturn = false;

        assertEq(expectedReturn, actualReturn);
    }

    function testSuccess_ownerOfVault_NonVault(address nonVault) public {
        assertEq(factory.ownerOfVault(nonVault), address(0));
    }

    /* ///////////////////////////////////////////////////////////////
                    VAULT VERSION MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testRevert_setNewVaultInfo_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        factory.setNewVaultInfo(address(mainRegistry), address(proxyAddr), Constants.upgradeRoot1To2, "");
        vm.stopPrank();
    }

    function testRevert_setNewVaultInfo_VersionRootIsZero(address mainRegistry_, address logic) public {
        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_SNVI: version root is zero");
        factory.setNewVaultInfo(mainRegistry_, logic, bytes32(0), "");
        vm.stopPrank();
    }

    function testRevert_setNewVaultInfo_LogicAddressIsZero(address mainRegistry_, bytes32 versionRoot) public {
        vm.assume(versionRoot != bytes32(0));

        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_SNVI: logic address is zero");
        factory.setNewVaultInfo(mainRegistry_, address(0), versionRoot, "");
        vm.stopPrank();
    }

    function testRevert_setNewVaultInfo_OwnerSetsNewVaultWithInfoMissingBaseCurrencyInMainRegistry(
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
        factory.setNewVaultInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, "");
        vm.stopPrank();
    }

    function testRevert_setNewVaultInfo_OwnerSetsNewVaultInfoWithDifferentBaseCurrencyInMainRegistry(
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
        factory.setNewVaultInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, "");
        vm.stopPrank();
    }

    function testSuccess_setNewVaultInfo(address mainRegistry_, address logic, bytes calldata data) public {
        vm.assume(logic != address(0));

        vm.prank(creatorAddress);
        factory = new FactoryExtension();
        assertTrue(factory.getVaultVersionRoot() == bytes32(0));

        uint256 latestVaultVersionPre = factory.latestVaultVersion();

        vm.startPrank(creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit VaultVersionAdded(uint16(latestVaultVersionPre + 1), mainRegistry_, logic, Constants.upgradeRoot1To2);
        factory.setNewVaultInfo(mainRegistry_, logic, Constants.upgradeRoot1To2, data);
        vm.stopPrank();

        (address registry_, address addresslogic_, bytes32 root, bytes memory data_) =
            factory.vaultDetails(latestVaultVersionPre + 1);
        assertEq(registry_, mainRegistry_);
        assertEq(addresslogic_, logic);
        assertEq(root, Constants.upgradeRoot1To2);
        assertEq(data_, data);
        assertEq(factory.latestVaultVersion(), latestVaultVersionPre + 1);
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultWithIdenticalBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic,
        bytes calldata data
    ) public {
        vm.assume(logic != address(0));
        vm.assume(newAssetAddress != address(0));

        uint256 latestVaultVersionPre = factory.latestVaultVersion();

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
        factory.setNewVaultInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, data);
        vm.stopPrank();

        assertEq(factory.latestVaultVersion(), ++latestVaultVersionPre);
    }

    function testSuccess_setNewVaultInfo_OwnerSetsNewVaultWithMoreBaseCurrenciesInMainRegistry(
        address newAssetAddress,
        address logic,
        bytes calldata data
    ) public {
        vm.assume(logic != address(0));
        vm.assume(newAssetAddress != address(0));

        uint256 latestVaultVersionPre = factory.latestVaultVersion();

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
        factory.setNewVaultInfo(address(mainRegistry2), logic, Constants.upgradeProof1To2, data);
        vm.stopPrank();

        assertEq(factory.latestVaultVersion(), ++latestVaultVersionPre);
    }

    function testRevert_blockVaultVersion_NonOwner(uint16 vaultVersion, address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);

        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion <= currentVersion);
        vm.assume(vaultVersion != 0);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        factory.blockVaultVersion(vaultVersion);
        vm.stopPrank();
    }

    function testRevert_blockVaultVersion_BlockNonExistingVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion > currentVersion || vaultVersion == 0);

        vm.startPrank(creatorAddress);
        vm.expectRevert("FTRY_BVV: Invalid version");
        factory.blockVaultVersion(vaultVersion);
        vm.stopPrank();
    }

    function testSuccess_blockVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion <= currentVersion);
        vm.assume(vaultVersion != 0);

        vm.startPrank(creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit VaultVersionBlocked(vaultVersion);
        factory.blockVaultVersion(vaultVersion);
        vm.stopPrank();

        assertTrue(factory.vaultVersionBlocked(vaultVersion));
    }

    /* ///////////////////////////////////////////////////////////////
                    VAULT LIQUIDATION LOGIC
    /////////////////////////////////////////////////////////////// */

    function testRevert_liquidate_NonVault(address liquidator_, address nonVault) public {
        vm.startPrank(nonVault);
        vm.expectRevert("FTRY: Not a vault");
        factory.liquidate(liquidator_);
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function testSuccess_allVaultsLength_VaultIdStartFromZero() public {
        assertEq(factory.allVaultsLength(), 0);
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
