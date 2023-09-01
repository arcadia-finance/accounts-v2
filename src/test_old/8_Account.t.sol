/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaAccountsFixture.f.sol";

import { TrustedCreditorMock } from "../mockups/TrustedCreditorMock.sol";
import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";
import { ActionMultiCall } from "../actions/MultiCall.sol";
import "../actions/utils/ActionData.sol";
import { MultiActionMock } from "../mockups/MultiActionMock.sol";

contract AccountTestExtension is AccountV1 {
    constructor(address mainReg_) AccountV1() {
        registry = mainReg_;
    }

    function getLengths() external view returns (uint256, uint256, uint256, uint256) {
        return (erc20Stored.length, erc721Stored.length, erc721TokenIds.length, erc1155Stored.length);
    }

    function setTrustedCreditor(address trustedCreditor_) public {
        trustedCreditor = trustedCreditor_;
    }

    function setIsTrustedCreditorSet(bool set) public {
        isTrustedCreditorSet = set;
    }

    function setFixedLiquidationCost(uint96 fixedLiquidationCost_) public {
        fixedLiquidationCost = fixedLiquidationCost_;
    }

    function setOwner(address newOwner) public {
        owner = newOwner;
    }

    function setRegistry(address registry_) public {
        registry = registry_;
    }

    function setLocked(uint256 locked_) public {
        locked = locked_;
    }
}

abstract contract accountTests is DeployArcadiaAccounts {
    using stdStorage for StdStorage;

    AccountTestExtension public account_;
    TrustedCreditorMock trustedCreditor;

    bytes3 public emptyBytes3;

    address public liquidator = address(8);

    struct Assets {
        address[] assetAddresses;
        uint256[] assetIds;
        uint256[] assetAmounts;
    }

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);

    //this is a before
    constructor() DeployArcadiaAccounts() {
        trustedCreditor = new TrustedCreditorMock();
        trustedCreditor.setBaseCurrency(address(dai));
        trustedCreditor.setLiquidator(liquidator);
    }

    //this is a before each
    function setUp() public virtual {
        vm.prank(accountOwner);
        account_ = new AccountTestExtension(address(mainRegistry));
        account_.setLocked(1);
    }

    /* ///////////////////////////////////////////////////////////////
                    HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function deployFactory() internal {
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(account_)).checked_write(
            true
        );
        stdstore.target(address(factory)).sig(factory.accountIndex.selector).with_key(address(account_)).checked_write(
            10
        );
        factory.setOwnerOf(accountOwner, 10);
    }

    function openMarginAccount() internal {
        vm.startPrank(accountOwner);
        account_.openTrustedMarginAccount(address(trustedCreditor));
        dai.approve(address(account_), type(uint256).max);
        bayc.setApprovalForAll(address(account_), true);
        mayc.setApprovalForAll(address(account_), true);
        dickButs.setApprovalForAll(address(account_), true);
        interleave.setApprovalForAll(address(account_), true);
        eth.approve(address(account_), type(uint256).max);
        link.approve(address(account_), type(uint256).max);
        snx.approve(address(account_), type(uint256).max);
        safemoon.approve(address(account_), type(uint256).max);
        vm.stopPrank();
    }

    function depositEthAndTakeMaxCredit(uint128 amountEth) public returns (uint256) {
        depositERC20InAccount(eth, amountEth, accountOwner);
        uint256 remainingCredit = account_.getFreeMargin();
        trustedCreditor.setOpenPosition(address(account_), amountEth);

        return remainingCredit;
    }

    function depositERC20InAccount(ERC20Mock token, uint128 amount, address sender)
        public
        virtual
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        vm.startPrank(sender);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositEthInAccount(uint8 amount, address sender) public returns (Assets memory assetInfo) {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.ethDecimals;

        vm.startPrank(sender);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        assetInfo = Assets({ assetAddresses: assetAddresses, assetIds: assetIds, assetAmounts: assetAmounts });
    }

    function depositLinkInAccount(uint8 amount, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.linkDecimals;

        vm.startPrank(sender);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositBaycInAccount(uint128[] memory tokenIds, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](tokenIds.length);
        assetIds = new uint256[](tokenIds.length);
        assetAmounts = new uint256[](tokenIds.length);

        uint256 tokenIdToWorkWith;
        for (uint256 i; i < tokenIds.length; ++i) {
            tokenIdToWorkWith = tokenIds[i];
            while (bayc.getOwnerOf(tokenIdToWorkWith) != address(0)) {
                tokenIdToWorkWith++;
            }

            bayc.mint(sender, tokenIdToWorkWith);
            assetAddresses[i] = address(bayc);
            assetIds[i] = tokenIdToWorkWith;
            assetAmounts[i] = 1;
        }

        vm.startPrank(sender);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function generateERC721DepositList(uint8 length)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](length);

        assetIds = new uint256[](length);

        assetAmounts = new uint256[](length);

        assetTypes = new uint256[](length);

        uint256 id = 10;
        for (uint256 i; i < length; ++i) {
            vm.prank(tokenCreatorAddress);
            bayc.mint(accountOwner, id);
            assetAddresses[i] = address(bayc);
            assetIds[i] = id;
            assetAmounts[i] = 1;
            assetTypes[i] = 1;
            ++id;
        }
    }
}

contract DeploymentTest is accountTests {
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_deployment() public {
        assertEq(account_.owner(), accountOwner);
        assertEq(account_.registry(), address(mainRegistry));
        assertEq(account_.ACCOUNT_VERSION(), 1);
        assertEq(account_.baseCurrency(), address(0));
    }
}

/* ///////////////////////////////////////////////////////////////
                   ACCOUNT MANAGEMENT
/////////////////////////////////////////////////////////////// */
contract AccountManagementTest is accountTests {
    using stdStorage for StdStorage;

    event BaseCurrencySet(address baseCurrency);

    function setUp() public override {
        vm.prank(accountOwner);
        account_ = new AccountTestExtension(address(mainRegistry));
        account_.setLocked(1);
    }
    // Test migrated to new test suite
    // function testRevert_initialize_AlreadyInitialized() public {}

    // Test migrated to new test suite
    // function testRevert_initialize_InvalidVersion() public {}

    // Test migrated to new test suite
    // function testSuccess_initialize(address owner_, uint16 accountVersion_) public {}

    // Test available in proxyUpgrade testfile
    // function testSuccess_upgradeAccount(
    //     address newImplementation,
    //     address newRegistry,
    //     uint16 newVersion,
    //     bytes calldata data
    // ) public

    // Test migrated to new test suite
    // function testRevert_upgradeAccount_byNonFactory(
    //     address newImplementation,
    //     address newRegistry,
    //     uint16 newVersion,
    //     address nonFactory,
    //     bytes calldata data
    // ) public {
    //     vm.assume(nonFactory != address(factory));

    //     vm.startPrank(nonFactory);
    //     vm.expectRevert("A: Only Factory");
    //     account_.upgradeAccount(newImplementation, newRegistry, newVersion, data);
    //     vm.stopPrank();
    // }

    // Test migrated to new test suite
    // function testRevert_upgradeAccount_InvalidAccountVersion(
    //     address newImplementation,
    //     address newRegistry,
    //     uint16 newVersion,
    //     bytes calldata data
    // ) public {
    //     vm.assume(newVersion != 1);

    //     //TrustedCreditor is set
    //     vm.prank(accountOwner);
    //     account_.openTrustedMarginAccount(address(trustedCreditor));

    //     //Check in creditor if new version is allowed should fail
    //     trustedCreditor.setCallResult(false);

    //     vm.startPrank(address(factory));
    //     vm.expectRevert("A_UA: Invalid Account version");
    //     account_.upgradeAccount(newImplementation, newRegistry, newVersion, data);
    //     vm.stopPrank();
    // }
}

/* ///////////////////////////////////////////////////////////////
                OWNERSHIP MANAGEMENT
/////////////////////////////////////////////////////////////// */
contract OwnershipManagementTest is accountTests {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_transferOwnership_NonFactory(address sender, address to) public {
        vm.assume(sender != address(factory));

        assertEq(accountOwner, account_.owner());

        vm.startPrank(sender);
        vm.expectRevert("A: Only Factory");
        account_.transferOwnership(to);
        vm.stopPrank();

        assertEq(accountOwner, account_.owner());
    }

    function testRevert_transferOwnership_InvalidRecipient() public {
        assertEq(accountOwner, account_.owner());

        vm.startPrank(address(factory));
        vm.expectRevert("A_TO: INVALID_RECIPIENT");
        account_.transferOwnership(address(0));
        vm.stopPrank();

        assertEq(accountOwner, account_.owner());
    }

    function testSuccess_transferOwnership(address to) public {
        vm.assume(to != address(0));

        assertEq(accountOwner, account_.owner());

        vm.prank(address(factory));
        account_.transferOwnership(to);

        assertEq(to, account_.owner());
    }
}

/* ///////////////////////////////////////////////////////////////
                BASE CURRENCY LOGIC
/////////////////////////////////////////////////////////////// */
contract BaseCurrencyLogicTest is accountTests {
    using stdStorage for StdStorage;

    event BaseCurrencySet(address baseCurrency);

    function setUp() public override {
        super.setUp();
        //openMarginAccount();
    }

    function testSuccess_setBaseCurrency() public {
        vm.startPrank(accountOwner);
        vm.expectEmit(true, true, true, true);
        emit BaseCurrencySet(address(eth));
        account_.setBaseCurrency(address(eth));
        vm.stopPrank();

        assertEq(account_.baseCurrency(), address(eth));
    }

    function testRevert_setBaseCurrency_NonAuthorized(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != accountOwner);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("A: Only Owner");
        account_.setBaseCurrency(address(eth));
        vm.stopPrank();
    }

    function testRevert_setBaseCurrency_TrustedCreditorSet() public {
        openMarginAccount();

        vm.startPrank(accountOwner);
        vm.expectRevert("A_SBC: Trusted Creditor Set");
        account_.setBaseCurrency(address(eth));
        vm.stopPrank();

        assertEq(account_.baseCurrency(), address(dai));
    }

    function testRevert_setBaseCurrency_BaseCurrencyNotFound(address baseCurrency_) public {
        vm.assume(baseCurrency_ != address(0));
        vm.assume(baseCurrency_ != address(eth));
        vm.assume(baseCurrency_ != address(dai));

        vm.startPrank(accountOwner);
        vm.expectRevert("A_SBC: baseCurrency not found");
        account_.setBaseCurrency(baseCurrency_);
        vm.stopPrank();
    }
}

/* ///////////////////////////////////////////////////////////////
            MARGIN ACCOUNT SETTINGS
/////////////////////////////////////////////////////////////// */
contract MarginAccountSettingsTest is accountTests {
    using stdStorage for StdStorage;

    event BaseCurrencySet(address baseCurrency);
    event TrustedMarginAccountChanged(address indexed protocol, address indexed liquidator);

    function setUp() public override {
        super.setUp();
        //deployFactory();
    }

    /// Migrated to new test suite
    /*     function testRevert_openTrustedMarginAccount_NonOwner(address unprivilegedAddress_, address trustedCreditor_)
        public
    {} */

    /// Migrated to new test suite
    /*     function testRevert_openTrustedMarginAccount_AlreadySet(address trustedCreditor_) public {
    } */

    /// Migrated to new test suite
    /*     function testRevert_openTrustedMarginAccount_OpeningMarginAccountFails() public {
    } */

    /// Migrated to new test suite
    /*     function testSuccess_openTrustedMarginAccount_DifferentBaseCurrency(
        address liquidator_,
        uint96 fixedLiquidationCost
    ) public {
    } */

    /// Migrated to new test suite
    /*     function testSuccess_openTrustedMarginAccount_SameBaseCurrency(address liquidator_, uint96 fixedLiquidationCost)
        public
    {} */

    function testRevert_closeTrustedMarginAccount_NonOwner(address nonOwner) public {
        vm.assume(nonOwner != accountOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert("A: Only Owner");
        account_.closeTrustedMarginAccount();
        vm.stopPrank();
    }

    function testRevert_closeTrustedMarginAccount_NonSetTrustedMarginAccount() public {
        vm.startPrank(accountOwner);
        vm.expectRevert("A_CTMA: NOT SET");
        account_.closeTrustedMarginAccount();
        vm.stopPrank();
    }

    function testRevert_closeTrustedMarginAccount_OpenPosition(uint256 debt_) public {
        vm.prank(accountOwner);
        account_.openTrustedMarginAccount(address(trustedCreditor));

        // Mock debt.
        vm.assume(debt_ > 0);
        trustedCreditor.setOpenPosition(address(account_), debt_);

        vm.startPrank(accountOwner);
        vm.expectRevert("A_CTMA: NON-ZERO OPEN POSITION");
        account_.closeTrustedMarginAccount();
        vm.stopPrank();
    }

    function testSuccess_closeTrustedMarginAccount() public {
        vm.prank(accountOwner);
        account_.openTrustedMarginAccount(address(trustedCreditor));

        vm.startPrank(accountOwner);
        vm.expectEmit(true, true, true, true);
        emit TrustedMarginAccountChanged(address(0), address(0));
        account_.closeTrustedMarginAccount();
        vm.stopPrank();

        assertTrue(!account_.isTrustedCreditorSet());
        assertTrue(account_.trustedCreditor() == address(0));
        assertTrue(account_.liquidator() == address(0));
    }
}

/* ///////////////////////////////////////////////////////////////
                    MARGIN REQUIREMENTS
/////////////////////////////////////////////////////////////// */
contract MarginRequirementsTest is accountTests {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
        deployFactory();
        openMarginAccount();
    }

    function testSuccess_isAccountHealthy_debtIncrease_InsufficientMargin(
        uint8 depositAmount,
        uint128 marginIncrease,
        uint128 openDebt,
        uint96 fixedLiquidationCost,
        uint8 collFac,
        uint8 liqFac
    ) public {
        vm.assume(uint256(marginIncrease) + openDebt <= type(uint256).max - fixedLiquidationCost);
        // Given: Risk Factors for baseCurrency are set
        vm.assume(collFac <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(liqFac <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: uint8(Constants.DaiBaseCurrency),
            asset: address(eth),
            collateralFactor: collFac,
            liquidationFactor: liqFac
        });
        vm.prank(creatorAddress);
        standardERC20PricingModule.setBatchRiskVariables(riskVars_);

        // And: Account has already used margin
        trustedCreditor.setOpenPosition(address(account_), openDebt);
        account_.setFixedLiquidationCost(fixedLiquidationCost);

        // And: Eth is deposited in the Account
        depositEthInAccount(depositAmount, accountOwner);

        // And: There is insufficient Collateral to take more margin
        uint256 collateralValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * collFac / 100;
        vm.assume(collateralValue < uint256(openDebt) + marginIncrease + fixedLiquidationCost);
        vm.assume(depositAmount > 0); // Division by 0

        // When: An Authorised protocol tries to take more margin against the Account
        (bool success, address creditor, uint256 version) = account_.isAccountHealthy(marginIncrease, 0);

        // Then: The action is not successful
        assertTrue(!success);
        assertEq(creditor, address(trustedCreditor));
        assertEq(version, 1);
    }

    function testSuccess_isAccountHealthy_debtIncrease_SufficientMargin(
        uint8 depositAmount,
        uint128 marginIncrease,
        uint128 openDebt,
        uint96 fixedLiquidationCost,
        uint8 collFac,
        uint8 liqFac
    ) public {
        vm.assume(uint256(marginIncrease) + openDebt <= type(uint256).max - fixedLiquidationCost);
        // Given: Risk Factors for baseCurrency are set
        vm.assume(collFac <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(liqFac <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: uint8(Constants.DaiBaseCurrency),
            asset: address(eth),
            collateralFactor: collFac,
            liquidationFactor: liqFac
        });
        vm.prank(creatorAddress);
        standardERC20PricingModule.setBatchRiskVariables(riskVars_);

        // And: Account has already used margin
        trustedCreditor.setOpenPosition(address(account_), openDebt);
        account_.setFixedLiquidationCost(fixedLiquidationCost);

        // And: Eth is deposited in the Account
        depositEthInAccount(depositAmount, accountOwner);

        // And: There is sufficient Collateral to take more margin
        uint256 collateralValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * collFac / 100;
        vm.assume(collateralValue >= uint256(openDebt) + marginIncrease + fixedLiquidationCost);
        vm.assume(depositAmount > 0); // Division by 0

        // When: An Authorised protocol tries to take more margin against the Account
        (bool success, address creditor, uint256 version) = account_.isAccountHealthy(marginIncrease, 0);

        // Then: The action is successful
        assertTrue(success);
        assertEq(creditor, address(trustedCreditor));
        assertEq(version, 1);
    }

    function testSuccess_isAccountHealthy_totalOpenDebt_InsufficientMargin(
        uint8 depositAmount,
        uint128 totalOpenDebt,
        uint96 fixedLiquidationCost,
        uint8 collFac,
        uint8 liqFac
    ) public {
        // Given: Risk Factors for baseCurrency are set
        vm.assume(collFac <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(liqFac <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: uint8(Constants.DaiBaseCurrency),
            asset: address(eth),
            collateralFactor: collFac,
            liquidationFactor: liqFac
        });
        vm.prank(creatorAddress);
        standardERC20PricingModule.setBatchRiskVariables(riskVars_);

        // And: Account has already used margin
        account_.setFixedLiquidationCost(fixedLiquidationCost);

        // And: Eth is deposited in the Account
        depositEthInAccount(depositAmount, accountOwner);

        // And: There is insufficient Collateral to take more margin
        uint256 collateralValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * collFac / 100;
        vm.assume(collateralValue < uint256(totalOpenDebt) + fixedLiquidationCost);
        vm.assume(depositAmount > 0); // Division by 0

        // When: An Authorised protocol tries to take more margin against the Account
        (bool success, address creditor, uint256 version) = account_.isAccountHealthy(0, totalOpenDebt);

        // Then: The action is not successful
        assertTrue(!success);
        assertEq(creditor, address(trustedCreditor));
        assertEq(version, 1);
    }

    function testSuccess_isAccountHealthy_totalOpenDebt_SufficientMargin(
        uint8 depositAmount,
        uint128 totalOpenDebt,
        uint96 fixedLiquidationCost,
        uint8 collFac,
        uint8 liqFac
    ) public {
        // Given: Risk Factors for baseCurrency are set
        vm.assume(collFac <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(liqFac <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: uint8(Constants.DaiBaseCurrency),
            asset: address(eth),
            collateralFactor: collFac,
            liquidationFactor: liqFac
        });
        vm.prank(creatorAddress);
        standardERC20PricingModule.setBatchRiskVariables(riskVars_);

        // And: Account has already used margin
        account_.setFixedLiquidationCost(fixedLiquidationCost);

        // And: Eth is deposited in the Account
        depositEthInAccount(depositAmount, accountOwner);

        // And: There is sufficient Collateral to take more margin
        uint256 collateralValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * collFac / 100;
        vm.assume(collateralValue >= uint256(totalOpenDebt) + fixedLiquidationCost);
        vm.assume(depositAmount > 0); // Division by 0

        // When: An Authorised protocol tries to take more margin against the Account
        (bool success, address creditor, uint256 version) = account_.isAccountHealthy(0, totalOpenDebt);

        // Then: The action is successful
        assertTrue(success);
        assertEq(creditor, address(trustedCreditor));
        assertEq(version, 1);
    }

    function testSuccess_getAccountValue(uint8 depositAmount) public {
        depositEthInAccount(depositAmount, accountOwner);

        uint256 expectedValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals);
        uint256 actualValue = account_.getAccountValue(address(dai));

        assertEq(expectedValue, actualValue);
    }

    function testSuccess_getAccountValue_GasUsage(uint8 depositAmount, uint128[] calldata tokenIds) public {
        vm.assume(tokenIds.length <= 5);
        vm.assume(depositAmount > 0);
        depositEthInAccount(depositAmount, accountOwner);
        depositLinkInAccount(depositAmount, accountOwner);
        depositBaycInAccount(tokenIds, accountOwner);

        uint256 gasStart = gasleft();
        account_.getAccountValue(address(dai));
        uint256 gasAfter = gasleft();
        emit log_int(int256(gasStart - gasAfter));
        assertLt(gasStart - gasAfter, 200_000);
    }

    function testSuccess_getLiquidationValue(uint8 depositAmount) public {
        depositEthInAccount(depositAmount, accountOwner);

        uint16 liqFactor_ = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;
        uint256 expectedValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * liqFactor_ / 100;

        uint256 actualValue = account_.getLiquidationValue();

        assertEq(expectedValue, actualValue);
    }

    function testSuccess_getCollateralValue(uint8 depositAmount) public {
        depositEthInAccount(depositAmount, accountOwner);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint256 expectedValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * depositAmount / 10 ** (18 - Constants.daiDecimals) * collFactor_ / 100;

        uint256 actualValue = account_.getCollateralValue();

        assertEq(expectedValue, actualValue);
    }

    function testSuccess_getUsedMargin(uint256 openDebt, uint96 fixedLiquidationCost) public {
        vm.assume(openDebt <= type(uint256).max - fixedLiquidationCost);

        trustedCreditor.setOpenPosition(address(account_), openDebt);
        account_.setFixedLiquidationCost(fixedLiquidationCost);

        assertEq(openDebt + fixedLiquidationCost, account_.getUsedMargin());
    }

    function testSuccess_getFreeMargin_ZeroInitially() public {
        uint256 remainingCredit = account_.getFreeMargin();
        assertEq(remainingCredit, 0);
    }

    function testSuccess_getFreeMargin_AfterFirstDeposit(uint8 amount) public {
        depositEthInAccount(amount, accountOwner);

        uint256 depositValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amount
            / 10 ** (18 - Constants.daiDecimals);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        uint256 expectedRemaining = (depositValue * collFactor_) / 100;
        assertEq(expectedRemaining, account_.getFreeMargin());
    }

    function testSuccess_getFreeMargin_AfterTopUp(uint8 amountEth, uint8 amountLink, uint128[] calldata tokenIds)
        public
    {
        vm.assume(tokenIds.length < 10 && tokenIds.length > 1);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        depositEthInAccount(amountEth, accountOwner);
        uint256 depositValueEth = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth;
        assertEq((depositValueEth / 10 ** (18 - Constants.daiDecimals) * collFactor_) / 100, account_.getFreeMargin());

        depositLinkInAccount(amountLink, accountOwner);
        uint256 depositValueLink =
            ((Constants.WAD * rateLinkToUsd) / 10 ** Constants.oracleLinkToUsdDecimals) * amountLink;
        assertEq(
            ((depositValueEth + depositValueLink) / 10 ** (18 - Constants.daiDecimals) * collFactor_) / 100,
            account_.getFreeMargin()
        );

        (, uint256[] memory assetIds,) = depositBaycInAccount(tokenIds, accountOwner);
        uint256 depositBaycValue = (
            (Constants.WAD * rateBaycToEth * rateEthToUsd)
                / 10 ** (Constants.oracleEthToUsdDecimals + Constants.oracleBaycToEthDecimals)
        ) * assetIds.length;
        assertEq(
            ((depositValueEth + depositValueLink + depositBaycValue) / 10 ** (18 - Constants.daiDecimals) * collFactor_)
                / 100,
            account_.getFreeMargin()
        );
    }

    function testSuccess_getFreeMargin_AfterTakingCredit(
        uint8 amountEth,
        uint128 amountCredit,
        uint16 fixedLiquidationCost
    ) public {
        uint256 depositValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth
            / 10 ** (18 - Constants.daiDecimals);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        vm.assume((depositValue * collFactor_) / 100 > uint256(amountCredit) + fixedLiquidationCost);
        account_.setFixedLiquidationCost(fixedLiquidationCost);
        depositEthInAccount(amountEth, accountOwner);

        trustedCreditor.setOpenPosition(address(account_), amountCredit);

        uint256 actualRemainingCredit = account_.getFreeMargin();
        uint256 expectedRemainingCredit = (depositValue * collFactor_) / 100 - amountCredit - fixedLiquidationCost;

        assertEq(expectedRemainingCredit, actualRemainingCredit);
    }

    function testSuccess_getFreeMargin_NoOverflows(uint128 amountEth, uint8 factor) public {
        vm.assume(amountEth < 10 * 10 ** 9 * 10 ** 18);
        vm.assume(amountEth > 0);

        depositERC20InAccount(eth, amountEth, accountOwner);
        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint256 amountCredit = (((amountEth * collFactor_) / 100) * factor) / 255;
        trustedCreditor.setOpenPosition(address(account_), amountCredit);

        uint256 currentValue = account_.getAccountValue(address(dai));
        uint256 openDebt = account_.getUsedMargin();

        uint256 maxAllowedCreditLocal;
        uint256 remainingCreditLocal;
        //gas: cannot overflow unless currentValue is more than
        // 1.15**57 *10**18 decimals, which is too many billions to write out
        maxAllowedCreditLocal = (currentValue * collFactor_) / 100;

        remainingCreditLocal = maxAllowedCreditLocal > openDebt ? maxAllowedCreditLocal - openDebt : 0;

        uint256 remainingCreditFetched = account_.getFreeMargin();

        //remainingCreditFetched has a lot of unchecked operations
        //-> we check that the checked operations never reverts and is
        //always equal to the unchecked operations
        assertEq(remainingCreditLocal, remainingCreditFetched);
    }
}

/* ///////////////////////////////////////////////////////////////
                    LIQUIDATION LOGIC
/////////////////////////////////////////////////////////////// */
contract LiquidationLogicTest is accountTests {
    using stdStorage for StdStorage;

    event TrustedMarginAccountChanged(address indexed protocol, address indexed liquidator);

    function setUp() public override {
        super.setUp();
        deployFactory();
        openMarginAccount();
    }

    // Test migrated to new test suite
    // function testRevert_liquidateAccount_NotAuthorized(address unprivilegedAddress_, uint128 openDebt) public {
    //     vm.assume(unprivilegedAddress_ != liquidator);

    //     vm.startPrank(unprivilegedAddress_);
    //     vm.expectRevert("A_LA: Only Liquidator");
    //     account_.liquidateAccount(openDebt);
    //     vm.stopPrank();
    // }

    // Test migrated to new test suite
    // function testRevert_liquidateAccount_AccountIsHealthy() public {
    //     vm.startPrank(liquidator);
    //     vm.expectRevert("A_LA: liqValue above usedMargin");
    //     account_.liquidateAccount(0);
    //     vm.stopPrank();
    // }

    // Test migrated to new test suite
    // function testSuccess_liquidateAccount(uint8 amountEth, uint128 openDebt, uint16 fixedLiquidationCost) public {
    //     vm.assume(openDebt > 0);

    //     uint256 depositValue = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth
    //         / 10 ** (18 - Constants.daiDecimals);

    //     uint16 liqFactor_ = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;

    //     vm.assume((depositValue * liqFactor_) / 100 < uint256(openDebt) + fixedLiquidationCost);
    //     depositEthInAccount(amountEth, accountOwner);

    //     trustedCreditor.setOpenPosition(address(account_), openDebt);

    //     account_.setFixedLiquidationCost(fixedLiquidationCost);

    //     vm.startPrank(liquidator);
    //     vm.expectEmit(true, true, true, true);
    //     emit TrustedMarginAccountChanged(address(0), address(0));
    //     (address originalOwner, address baseCurrency, address trustedCreditor_) = account_.liquidateAccount(openDebt);
    //     vm.stopPrank();

    //     assertEq(originalOwner, accountOwner);
    //     assertEq(baseCurrency, address(dai));
    //     assertEq(trustedCreditor_, address(trustedCreditor));

    //     assertEq(account_.owner(), liquidator);
    //     assertEq(account_.isTrustedCreditorSet(), false);
    //     assertEq(account_.trustedCreditor(), address(0));
    //     assertEq(account_.fixedLiquidationCost(), 0);

    //     uint256 index = factory.accountIndex(address(account_));
    //     assertEq(factory.ownerOf(index), liquidator);
    // }
}

/*///////////////////////////////////////////////////////////////
                ASSET MANAGEMENT LOGIC
///////////////////////////////////////////////////////////////*/
contract AccountActionTest is accountTests {
    using stdStorage for StdStorage;

    ActionMultiCall public action;
    MultiActionMock public multiActionMock;

    AccountTestExtension public proxy_;

    event AssetManagerSet(address indexed owner, address indexed assetManager, bool value);

    function depositERC20InAccount(ERC20Mock token, uint128 amount, address sender)
        public
        override
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        token.balanceOf(0x0000000000000000000000000000000000000006);

        vm.startPrank(sender);
        token.approve(address(proxy_), amount);
        proxy_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();
        deployFactory();

        action = new ActionMultiCall();
        deal(address(eth), address(action), 1000 * 10 ** 20, false);

        vm.startPrank(creatorAddress);
        account = new AccountTestExtension(address(mainRegistry));
        factory.setLatestAccountversion(0);
        factory.setNewAccountInfo(address(mainRegistry), address(account), Constants.upgradeProof1To2, "");
        vm.stopPrank();

        vm.startPrank(accountOwner);
        proxyAddr = factory.createAccount(12_345_678, 0, address(0), address(0));
        proxy_ = AccountTestExtension(proxyAddr);
        vm.stopPrank();

        depositERC20InAccount(eth, 1000 * 10 ** 18, accountOwner);
        vm.startPrank(creatorAddress);
        mainRegistry.setAllowedAction(address(action), true);

        vm.stopPrank();
    }

    function testRevert_setAssetManager_NonOwner(address nonOwner, address assetManager, bool value) public {
        vm.assume(nonOwner != accountOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert("A: Only Owner");
        account_.setAssetManager(assetManager, value);
        vm.stopPrank();
    }

    function testSuccess_setAssetManager(address assetManager, bool startValue, bool endvalue) public {
        vm.startPrank(accountOwner);
        vm.expectEmit(true, true, true, true);
        emit AssetManagerSet(accountOwner, assetManager, startValue);
        account_.setAssetManager(assetManager, startValue);
        vm.stopPrank();
        assertEq(account_.isAssetManager(accountOwner, assetManager), startValue);

        vm.startPrank(accountOwner);
        vm.expectEmit(true, true, true, true);
        emit AssetManagerSet(accountOwner, assetManager, endvalue);
        account_.setAssetManager(assetManager, endvalue);
        vm.stopPrank();
        assertEq(account_.isAssetManager(accountOwner, assetManager), endvalue);
    }

    function testRevert_accountManagementAction_NonAssetManager(address sender, address assetManager) public {
        vm.assume(sender != accountOwner);
        vm.assume(sender != assetManager);
        vm.assume(sender != address(0));

        vm.prank(accountOwner);
        proxy_.setAssetManager(assetManager, true);

        vm.startPrank(sender);
        vm.expectRevert("A: Only Asset Manager");
        proxy_.accountManagementAction(address(action), new bytes(0));
        vm.stopPrank();
    }

    function testRevert_accountManagementAction_OwnerChanged(address assetManager) public {
        vm.assume(assetManager != address(0));
        address newOwner = address(60); //Annoying to fuzz since it often fuzzes to existing contracts without an onERC721Received
        vm.assume(assetManager != newOwner);

        vm.prank(accountOwner);
        proxy_.setAssetManager(assetManager, true);

        vm.prank(accountOwner);
        factory.safeTransferFrom(accountOwner, newOwner, address(proxy_));

        vm.startPrank(assetManager);
        vm.expectRevert("A: Only Asset Manager");
        proxy_.accountManagementAction(address(action), new bytes(0));
        vm.stopPrank();
    }

    function testRevert_accountManagementAction_actionNotAllowed(address action_) public {
        vm.assume(action_ != address(action));

        vm.startPrank(accountOwner);
        vm.expectRevert("A_AMA: Action not allowed");
        proxy_.accountManagementAction(action_, new bytes(0));
        vm.stopPrank();
    }

    function testRevert_accountManagementAction_tooManyAssets(uint8 arrLength) public {
        vm.assume(arrLength > proxy_.ASSET_LIMIT() && arrLength < 50);

        address[] memory assetAddresses = new address[](arrLength);

        uint256[] memory assetIds = new uint256[](arrLength);

        uint256[] memory assetAmounts = new uint256[](arrLength);

        uint256[] memory assetTypes = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts, assetTypes) = generateERC721DepositList(arrLength);

        bytes[] memory data = new bytes[](0);
        address[] memory to = new address[](0);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0),
            actionBalances: new uint256[](0)
        });

        ActionData memory assetDataIn = ActionData({
            assets: assetAddresses,
            assetIds: assetIds,
            assetAmounts: assetAmounts,
            assetTypes: assetTypes,
            actionBalances: new uint256[](0)
        });

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        //Already sent asset to action contract
        uint256 id = 10;
        for (uint256 i; i < arrLength; ++i) {
            vm.prank(accountOwner);
            bayc.transferFrom(accountOwner, address(action), id);
            ++id;
        }
        vm.prank(address(action));
        bayc.setApprovalForAll(address(proxy_), true);

        vm.prank(accountOwner);
        vm.expectRevert("A_D: Too many assets");
        proxy_.accountManagementAction(address(action), callData);
    }

    // Migrated to new test suite
    /*     function testSuccess_accountManagementAction_Owner(uint128 debtAmount, uint32 fixedLiquidationCost) public {
        multiActionMock = new MultiActionMock();

        proxy_.setFixedLiquidationCost(fixedLiquidationCost);

        vm.prank(accountOwner);
        proxy_.setBaseCurrency(address(eth));

        proxy_.setTrustedCreditor(address(trustedCreditor));
        proxy_.setIsTrustedCreditorSet(true);
        trustedCreditor.setOpenPosition(address(proxy_), debtAmount);

        (uint256 ethRate,) = oracleHub.getRate(oracleEthToUsdArr, 0);
        (uint256 linkRate,) = oracleHub.getRate(oracleLinkToUsdArr, 0);

        uint256 ethToLinkRatio = ethRate / linkRate;
        vm.assume(1000 * 10 ** 18 + ((uint256(debtAmount) + fixedLiquidationCost) * ethToLinkRatio) < type(uint256).max);

        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(multiActionMock), 1000 * 10 ** 18 + uint256(debtAmount)
        );
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(eth),
            address(link),
            1000 * 10 ** 18 + uint256(debtAmount),
            1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );
        data[2] = abi.encodeWithSignature(
            "approve(address,uint256)", address(proxy_), 1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );

        vm.prank(tokenCreatorAddress);
        link.mint(address(multiActionMock), 1000 * 10 ** 18 + debtAmount * ethToLinkRatio);

        vm.prank(tokenCreatorAddress);
        eth.mint(address(action), debtAmount);

        to[0] = address(eth);
        to[1] = address(multiActionMock);
        to[2] = address(link);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(eth);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = 1000 * 10 ** 18;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(link);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        vm.startPrank(accountOwner);
        proxy_.accountManagementAction(address(action), callData);
        vm.stopPrank();
    } */

    // Migrated to new test suite
    /*     function testSuccess_accountManagementAction_AssetManager(
        uint128 debtAmount,
        uint32 fixedLiquidationCost,
        address assetManager
    ) public {
        vm.assume(accountOwner != assetManager);
        multiActionMock = new MultiActionMock();

        proxy_.setFixedLiquidationCost(fixedLiquidationCost);

        vm.prank(accountOwner);
        proxy_.setBaseCurrency(address(eth));

        vm.prank(accountOwner);
        proxy_.setAssetManager(assetManager, true);

        proxy_.setTrustedCreditor(address(trustedCreditor));
        proxy_.setIsTrustedCreditorSet(true);
        trustedCreditor.setOpenPosition(address(proxy_), debtAmount);

        (uint256 ethRate,) = oracleHub.getRate(oracleEthToUsdArr, 0);
        (uint256 linkRate,) = oracleHub.getRate(oracleLinkToUsdArr, 0);

        uint256 ethToLinkRatio = ethRate / linkRate;
        vm.assume(1000 * 10 ** 18 + ((uint256(debtAmount) + fixedLiquidationCost) * ethToLinkRatio) < type(uint256).max);

        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(multiActionMock), 1000 * 10 ** 18 + uint256(debtAmount)
        );
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(eth),
            address(link),
            1000 * 10 ** 18 + uint256(debtAmount),
            1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );
        data[2] = abi.encodeWithSignature(
            "approve(address,uint256)", address(proxy_), 1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );

        vm.prank(tokenCreatorAddress);
        link.mint(address(multiActionMock), 1000 * 10 ** 18 + debtAmount * ethToLinkRatio);

        vm.prank(tokenCreatorAddress);
        eth.mint(address(action), debtAmount);

        to[0] = address(eth);
        to[1] = address(multiActionMock);
        to[2] = address(link);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(eth);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = 1000 * 10 ** 18;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(link);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        vm.startPrank(accountOwner);
        proxy_.accountManagementAction(address(action), callData);
        vm.stopPrank();
    } */

    // Migrated to new test suite
    /*     function testRevert_accountManagementAction_InsufficientReturned(uint128 debtAmount, uint32 fixedLiquidationCost)
        public
    {
        vm.assume(debtAmount > 0);

        proxy_.setFixedLiquidationCost(fixedLiquidationCost);

        multiActionMock = new MultiActionMock();

        vm.prank(accountOwner);
        proxy_.setBaseCurrency(address(eth));

        proxy_.setTrustedCreditor(address(trustedCreditor));
        proxy_.setIsTrustedCreditorSet(true);
        trustedCreditor.setOpenPosition(address(proxy_), debtAmount);

        (uint256 ethRate,) = oracleHub.getRate(oracleEthToUsdArr, 0);
        (uint256 linkRate,) = oracleHub.getRate(oracleLinkToUsdArr, 0);

        uint256 ethToLinkRatio = ethRate / linkRate;
        vm.assume(1000 * 10 ** 18 + ((uint256(debtAmount) + fixedLiquidationCost) * ethToLinkRatio) < type(uint256).max);

        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(multiActionMock), 1000 * 10 ** 18 + uint256(debtAmount)
        );
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(eth),
            address(link),
            1000 * 10 ** 18 + uint256(debtAmount),
            0
        );
        data[2] = abi.encodeWithSignature(
            "approve(address,uint256)", address(proxy_), 1000 * 10 ** 18 + uint256(debtAmount) * ethToLinkRatio
        );

        vm.prank(tokenCreatorAddress);
        eth.mint(address(action), debtAmount);

        to[0] = address(eth);
        to[1] = address(multiActionMock);
        to[2] = address(link);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(eth);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = 1000 * 10 ** 18;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(link);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        bytes memory callData = abi.encode(assetDataOut, assetDataIn, to, data);

        vm.startPrank(accountOwner);
        vm.expectRevert("A_AMA: Account Unhealthy");
        proxy_.accountManagementAction(address(action), callData);
        vm.stopPrank();
    }*/
}

/* ///////////////////////////////////////////////////////////////
            ASSET DEPOSIT/WITHDRAWN LOGIC
/////////////////////////////////////////////////////////////// */
contract AssetManagementTest is accountTests {
    using stdStorage for StdStorage;

    AccountTestExtension public account2;

    function setUp() public override {
        super.setUp();
        deployFactory();
        openMarginAccount();
    }

    function testRevert_deposit_NonOwner(address sender) public {
        vm.assume(sender != accountOwner);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10 * 10 ** Constants.ethDecimals;

        vm.startPrank(sender);
        vm.expectRevert("A: Only Owner");
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_deposit_tooManyAssets(uint8 arrLength) public {
        vm.assume(arrLength > account_.ASSET_LIMIT() && arrLength < 50);

        address[] memory assetAddresses = new address[](arrLength);

        uint256[] memory assetIds = new uint256[](arrLength);

        uint256[] memory assetAmounts = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts,) = generateERC721DepositList(arrLength);

        vm.prank(accountOwner);
        vm.expectRevert("A_D: Too many assets");
        account_.deposit(assetAddresses, assetIds, assetAmounts);
    }

    function testRevert_deposit_tooManyAssetsNotAtOnce(uint8 arrLength) public {
        vm.assume(uint256(arrLength) + 1 > account_.ASSET_LIMIT() && arrLength < 50);

        //deposit a single asset first
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10 * 10 ** Constants.ethDecimals;

        vm.prank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);

        assertEq(account_.erc20Stored(0), address(eth));
        assertEq(account_.erc20Balances(address(eth)), eth.balanceOf(address(account_)));

        //then try to go over the asset limit
        assetAddresses = new address[](arrLength);

        assetIds = new uint256[](arrLength);

        assetAmounts = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts,) = generateERC721DepositList(arrLength);

        vm.prank(accountOwner);
        vm.expectRevert("A_D: Too many assets");
        account_.deposit(assetAddresses, assetIds, assetAmounts);
    }

    //input as uint8 to prevent too long lists as fuzz input
    function testRevert_deposit_LengthOfListDoesNotMatch(uint8 addrLen, uint8 idLen, uint8 amountLen) public {
        vm.assume((addrLen != idLen && addrLen != amountLen));
        vm.assume(
            addrLen <= account_.ASSET_LIMIT() && idLen <= account_.ASSET_LIMIT() && amountLen <= account_.ASSET_LIMIT()
        );

        address[] memory assetAddresses = new address[](addrLen);
        for (uint256 i; i < addrLen; ++i) {
            assetAddresses[i] = address(uint160(i));
        }

        uint256[] memory assetIds = new uint256[](idLen);
        for (uint256 j; j < idLen; j++) {
            assetIds[j] = j;
        }

        uint256[] memory assetAmounts = new uint256[](amountLen);
        for (uint256 k; k < amountLen; k++) {
            assetAmounts[k] = k;
        }

        vm.startPrank(accountOwner);
        vm.expectRevert("MR_BPD: LENGTH_MISMATCH");
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_deposit_ERC20IsNotWhitelisted(address inputAddr) public {
        vm.assume(inputAddr != address(eth));
        vm.assume(inputAddr != address(link));
        vm.assume(inputAddr != address(snx));
        vm.assume(inputAddr != address(bayc));
        vm.assume(inputAddr != address(interleave));
        vm.assume(inputAddr != address(dai));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = inputAddr;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1000;

        vm.startPrank(accountOwner);
        vm.expectRevert();
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_deposit_ERC721IsNotWhitelisted(address inputAddr, uint256 id) public {
        vm.assume(inputAddr != address(dai));
        vm.assume(inputAddr != address(eth));
        vm.assume(inputAddr != address(link));
        vm.assume(inputAddr != address(snx));
        vm.assume(inputAddr != address(bayc));
        vm.assume(inputAddr != address(interleave));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = inputAddr;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(accountOwner);
        vm.expectRevert();
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_deposit_UnknownAssetType(uint96 assetType) public {
        vm.assume(assetType >= 3);

        mainRegistry.setAssetType(address(eth), assetType);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(accountOwner);
        vm.expectRevert("A_D: Unknown asset type");
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testSuccess_deposit_ZeroAmount() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 0;

        vm.prank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);

        (uint256 erc20Len,,,) = account_.getLengths();

        assertEq(erc20Len, 0);
    }

    function testSuccess_deposit_SingleERC20(uint16 amount) public {
        vm.assume(amount > 0);
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.ethDecimals;

        vm.prank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);

        assertEq(account_.erc20Stored(0), address(eth));
        assertEq(account_.erc20Balances(address(eth)), eth.balanceOf(address(account_)));
    }

    function testSuccess_deposit_MultipleSameERC20(uint16 amount) public {
        vm.assume(amount <= 50_000);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.linkDecimals;

        vm.startPrank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        (uint256 erc20StoredDuring,,,) = account_.getLengths();

        account_.deposit(assetAddresses, assetIds, assetAmounts);
        (uint256 erc20StoredAfter,,,) = account_.getLengths();
        vm.stopPrank();

        assertEq(erc20StoredDuring, erc20StoredAfter);
        assertEq(account_.erc20Balances(address(eth)), eth.balanceOf(address(account_)));
    }

    function testSuccess_deposit_SingleERC721() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.prank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);

        assertEq(account_.erc721Stored(0), address(bayc));
    }

    function testSuccess_deposit_MultipleERC721() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.prank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);

        assertEq(account_.erc721Stored(0), address(bayc));
        (, uint256 erc721LengthFirst,,) = account_.getLengths();
        assertEq(erc721LengthFirst, 1);

        assetIds[0] = 3;
        vm.prank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);

        assertEq(account_.erc721Stored(1), address(bayc));
        (, uint256 erc721LengthSecond,,) = account_.getLengths();
        assertEq(erc721LengthSecond, 2);

        assertEq(account_.erc721TokenIds(0), 1);
        assertEq(account_.erc721TokenIds(1), 3);
    }

    function testSuccess_deposit_SingleERC1155() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.prank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);

        assertEq(account_.erc1155Stored(0), address(interleave));
        assertEq(account_.erc1155TokenIds(0), 1);
        assertEq(account_.erc1155Balances(address(interleave), 1), interleave.balanceOf(address(account_), 1));
    }

    function testSuccess_deposit_ERC20ERC721(uint8 erc20Amount1, uint8 erc20Amount2) public {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(bayc);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 2;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = erc20Amount1 * 10 ** Constants.ethDecimals;
        assetAmounts[1] = erc20Amount2 * 10 ** Constants.linkDecimals;
        assetAmounts[2] = 1;

        vm.prank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        assertEq(account_.erc20Balances(address(eth)), eth.balanceOf(address(account_)));
        assertEq(account_.erc20Balances(address(eth)), erc20Amount1 * 10 ** Constants.ethDecimals);
        assertEq(account_.erc20Balances(address(link)), link.balanceOf(address(account_)));
        assertEq(account_.erc20Balances(address(link)), erc20Amount2 * 10 ** Constants.linkDecimals);
    }

    function testSuccess_deposit_ERC20ERC721ERC1155(uint8 erc20Amount1, uint8 erc20Amount2, uint8 erc1155Amount)
        public
    {
        address[] memory assetAddresses = new address[](4);
        assetAddresses[0] = address(eth);
        assetAddresses[1] = address(link);
        assetAddresses[2] = address(bayc);
        assetAddresses[3] = address(interleave);

        uint256[] memory assetIds = new uint256[](4);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 0;
        assetIds[3] = 1;

        uint256[] memory assetAmounts = new uint256[](4);
        assetAmounts[0] = erc20Amount1 * 10 ** Constants.ethDecimals;
        assetAmounts[1] = erc20Amount2 * 10 ** Constants.linkDecimals;
        assetAmounts[2] = 1;
        assetAmounts[3] = erc1155Amount;

        vm.prank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        assertEq(account_.erc20Balances(address(eth)), eth.balanceOf(address(account_)));
        assertEq(account_.erc20Balances(address(eth)), erc20Amount1 * 10 ** Constants.ethDecimals);
        assertEq(account_.erc20Balances(address(link)), link.balanceOf(address(account_)));
        assertEq(account_.erc20Balances(address(link)), erc20Amount2 * 10 ** Constants.linkDecimals);
        assertEq(account_.erc1155Balances(address(interleave), 1), interleave.balanceOf(address(account_), 1));
        assertEq(account_.erc1155Balances(address(interleave), 1), erc1155Amount);
    }

    function testRevert_withdraw_NonOwner(uint8 depositAmount, uint8 withdrawalAmount, address sender) public {
        vm.assume(sender != accountOwner);
        vm.assume(depositAmount > withdrawalAmount);
        Assets memory assetInfo = depositEthInAccount(depositAmount, accountOwner);

        assetInfo.assetAmounts[0] = withdrawalAmount * 10 ** Constants.ethDecimals;
        vm.startPrank(sender);
        vm.expectRevert("A: Only Owner");
        account_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);
    }

    //input as uint8 to prevent too long lists as fuzz input
    function testRevert_withdraw_LengthOfListDoesNotMatch(uint8 addrLen, uint8 idLen, uint8 amountLen) public {
        vm.assume((addrLen != idLen && addrLen != amountLen));

        address[] memory assetAddresses = new address[](addrLen);
        for (uint256 i; i < addrLen; ++i) {
            assetAddresses[i] = address(uint160(i));
        }

        uint256[] memory assetIds = new uint256[](idLen);
        for (uint256 j; j < idLen; j++) {
            assetIds[j] = j;
        }

        uint256[] memory assetAmounts = new uint256[](amountLen);
        for (uint256 k; k < amountLen; k++) {
            assetAmounts[k] = k;
        }

        vm.startPrank(accountOwner);
        vm.expectRevert("MR_BPW: LENGTH_MISMATCH");
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_UnknownAssetType(uint96 assetType) public {
        vm.assume(assetType >= 3);
        depositEthInAccount(5, accountOwner);

        mainRegistry.setAssetType(address(eth), assetType);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(accountOwner);
        vm.expectRevert("A_W: Unknown asset type");
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_MoreThanMaxExposure(uint256 amountWithdraw, uint128 maxExposure) public {
        vm.assume(amountWithdraw > maxExposure);
        vm.prank(creatorAddress);
        standardERC20PricingModule.setExposureOfAsset(address(eth), maxExposure);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountWithdraw;

        vm.startPrank(accountOwner);
        vm.expectRevert(stdError.arithmeticError);
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC721TransferAndWithdrawTokenOneERC721Deposited() public {
        bayc.mint(accountOwner, 20);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 20;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(accountOwner);
        bayc.approve(address(account_), 20);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        vm.prank(accountOwner);
        account2 = new AccountTestExtension(address(mainRegistry));
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(account2)).checked_write(
            true
        );
        stdstore.target(address(factory)).sig(factory.accountIndex.selector).with_key(address(account2)).checked_write(
            11
        );
        factory.setOwnerOf(accountOwner, 11);

        mayc.mint(accountOwner, 10);
        mayc.mint(accountOwner, 11);

        assetAddresses[0] = address(mayc);
        assetIds[0] = 10;

        vm.startPrank(accountOwner);
        mayc.approve(address(account2), 10);
        account2.deposit(assetAddresses, assetIds, assetAmounts);
        mayc.safeTransferFrom(accountOwner, address(account_), 11);
        vm.stopPrank();

        assetIds[0] = 11;

        vm.startPrank(accountOwner);
        vm.expectRevert("A_W721: Unknown asset");
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC721TransferAndWithdrawTokenNotOneERC721Deposited(uint128[] calldata tokenIdsDeposit)
        public
    {
        vm.assume(tokenIdsDeposit.length < account_.ASSET_LIMIT());
        vm.assume(tokenIdsDeposit.length != 1);

        depositBaycInAccount(tokenIdsDeposit, accountOwner);

        vm.prank(accountOwner);
        account2 = new AccountTestExtension(address(mainRegistry));
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(account2)).checked_write(
            true
        );
        stdstore.target(address(factory)).sig(factory.accountIndex.selector).with_key(address(account2)).checked_write(
            11
        );
        factory.setOwnerOf(accountOwner, 11);

        mayc.mint(accountOwner, 10);
        mayc.mint(accountOwner, 11);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 10;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(accountOwner);
        mayc.approve(address(account2), 10);
        account2.deposit(assetAddresses, assetIds, assetAmounts);
        mayc.safeTransferFrom(accountOwner, address(account_), 11);
        vm.stopPrank();

        assetIds[0] = 11;

        vm.startPrank(accountOwner);
        vm.expectRevert("A_W721: Unknown asset");
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC20UnsufficientCollateral(
        uint8 baseAmountDeposit,
        uint24 baseAmountCredit,
        uint32 fixedLiquidationCost,
        uint8 baseAmountWithdraw
    ) public {
        vm.assume(baseAmountCredit > 0);
        vm.assume(baseAmountWithdraw > 0);
        vm.assume(baseAmountWithdraw < baseAmountDeposit);

        uint256 valueDeposit = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountDeposit / 10 ** (18 - Constants.daiDecimals);
        uint256 amountCredit = baseAmountCredit * 10 ** Constants.daiDecimals;
        uint256 amountWithdraw = baseAmountWithdraw * 10 ** Constants.ethDecimals;
        uint256 ValueWithdraw = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountWithdraw / 10 ** (18 - Constants.daiDecimals);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        vm.assume(amountCredit + fixedLiquidationCost <= (valueDeposit * collFactor_) / 100);
        vm.assume(amountCredit + fixedLiquidationCost > ((valueDeposit - ValueWithdraw) * collFactor_) / 100);

        Assets memory assetInfo = depositEthInAccount(baseAmountDeposit, accountOwner);

        account_.setFixedLiquidationCost(fixedLiquidationCost);

        trustedCreditor.setOpenPosition(address(account_), amountCredit);

        assetInfo.assetAmounts[0] = amountWithdraw;

        vm.startPrank(accountOwner);
        vm.expectRevert("A_W: Account Unhealthy");
        account_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC721UnsufficientCollateral(
        uint128[] calldata tokenIdsDeposit,
        uint8 amountsWithdrawn
    ) public {
        vm.assume(tokenIdsDeposit.length < account_.ASSET_LIMIT());

        (, uint256[] memory assetIds,) = depositBaycInAccount(tokenIdsDeposit, accountOwner);
        vm.assume(assetIds.length >= amountsWithdrawn && assetIds.length > 1 && amountsWithdrawn > 1);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint256 rateInUsd = (((Constants.WAD * rateBaycToEth) / 10 ** Constants.oracleBaycToEthDecimals) * rateEthToUsd)
            / 10 ** Constants.oracleEthToUsdDecimals / 10 ** (18 - Constants.daiDecimals);

        uint128 maxAmountCredit = uint128(((assetIds.length - amountsWithdrawn) * rateInUsd * collFactor_) / 100);

        trustedCreditor.setOpenPosition(address(account_), maxAmountCredit + 1);

        uint256[] memory withdrawalIds = new uint256[](amountsWithdrawn);
        address[] memory withdrawalAddresses = new address[](amountsWithdrawn);
        uint256[] memory withdrawalAmounts = new uint256[](amountsWithdrawn);
        for (uint256 i; i < amountsWithdrawn; ++i) {
            withdrawalIds[i] = assetIds[i];
            withdrawalAddresses[i] = address(bayc);
            withdrawalAmounts[i] = 1;
        }

        vm.startPrank(accountOwner);
        vm.expectRevert("A_W: Account Unhealthy");
        account_.withdraw(withdrawalAddresses, withdrawalIds, withdrawalAmounts);
        vm.stopPrank();
    }

    function testSuccess_withdraw_ERC20NoDebt(uint8 baseAmountDeposit, uint32 fixedLiquidationCost) public {
        vm.assume(baseAmountDeposit > 0);
        uint256 valueAmount = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountDeposit / 10 ** (18 - Constants.daiDecimals);

        Assets memory assetInfo = depositEthInAccount(baseAmountDeposit, accountOwner);

        uint256 accountValue = account_.getAccountValue(address(dai));

        assertEq(accountValue, valueAmount);

        account_.setFixedLiquidationCost(fixedLiquidationCost);

        vm.startPrank(accountOwner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(account_), accountOwner, assetInfo.assetAmounts[0]);
        account_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);
        vm.stopPrank();

        uint256 accountValueAfter = account_.getAccountValue(address(dai));
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            account_.generateAssetData();
        assertEq(accountValueAfter, 0);
        assertEq(assetAddresses.length, 0);
        assertEq(assetIds.length, 0);
        assertEq(assetAmounts.length, 0);
    }

    function testSuccess_withdraw_ERC20AfterTakingCredit(
        uint8 baseAmountDeposit,
        uint32 baseAmountCredit,
        uint32 fixedLiquidationCost,
        uint8 baseAmountWithdraw
    ) public {
        uint256 valueDeposit = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountDeposit / 10 ** (18 - Constants.daiDecimals);
        uint128 amountCredit = uint128(baseAmountCredit * 10 ** Constants.daiDecimals);
        uint256 amountWithdraw = baseAmountWithdraw * 10 ** Constants.ethDecimals;
        uint256 valueWithdraw = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountWithdraw / 10 ** (18 - Constants.daiDecimals);
        vm.assume(baseAmountWithdraw < baseAmountDeposit);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        vm.assume(amountCredit + fixedLiquidationCost <= ((valueDeposit - valueWithdraw) * collFactor_) / 100);

        account_.setFixedLiquidationCost(fixedLiquidationCost);

        trustedCreditor.setOpenPosition(address(account_), amountCredit);

        Assets memory assetInfo = depositEthInAccount(baseAmountDeposit, accountOwner);
        assetInfo.assetAmounts[0] = amountWithdraw;

        vm.prank(accountOwner);
        account_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);

        uint256 actualValue = account_.getAccountValue(address(dai));
        uint256 expectedValue = valueDeposit - valueWithdraw;

        assertEq(expectedValue, actualValue);
    }

    function testSuccess_withdraw_ERC721AfterTakingCredit(uint128[] calldata tokenIdsDeposit, uint8 baseAmountCredit)
        public
    {
        vm.assume(tokenIdsDeposit.length < account_.ASSET_LIMIT());
        uint128 amountCredit = uint128(baseAmountCredit * 10 ** Constants.daiDecimals);

        (, uint256[] memory assetIds,) = depositBaycInAccount(tokenIdsDeposit, accountOwner);

        uint256 randomAmounts = assetIds.length > 0
            ? uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "testWithrawERC721AfterTakingCredit(uint256[],uint8)", assetIds, baseAmountCredit
                    )
                )
            ) % assetIds.length
            : 0;

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        uint256 rateInUsd = (((Constants.WAD * rateBaycToEth) / 10 ** Constants.oracleBaycToEthDecimals) * rateEthToUsd)
            / 10 ** Constants.oracleEthToUsdDecimals / 10 ** (18 - Constants.daiDecimals);
        uint256 valueOfDeposit = rateInUsd * assetIds.length;

        uint256 valueOfWithdrawal = rateInUsd * randomAmounts;

        vm.assume((valueOfDeposit * collFactor_) / 100 >= amountCredit);
        vm.assume(valueOfWithdrawal < valueOfDeposit);
        vm.assume(amountCredit < ((valueOfDeposit - valueOfWithdrawal) * collFactor_) / 100);

        trustedCreditor.setOpenPosition(address(account_), amountCredit);

        uint256[] memory withdrawalIds = new uint256[](randomAmounts);
        address[] memory withdrawalAddresses = new address[](randomAmounts);
        uint256[] memory withdrawalAmounts = new uint256[](randomAmounts);
        for (uint256 i; i < randomAmounts; ++i) {
            withdrawalIds[i] = assetIds[i];
            withdrawalAddresses[i] = address(bayc);
            withdrawalAmounts[i] = 1;
        }

        vm.prank(accountOwner);
        account_.withdraw(withdrawalAddresses, withdrawalIds, withdrawalAmounts);

        uint256 actualValue = account_.getAccountValue(address(dai));
        uint256 expectedValue = valueOfDeposit - valueOfWithdrawal;

        assertEq(expectedValue, actualValue);
    }

    function testRevert_skim_NonOwner(address sender) public {
        vm.assume(sender != accountOwner);

        vm.startPrank(sender);
        vm.expectRevert("A_S: Only owner can skim");
        account_.skim(address(eth), 0, 0);
        vm.stopPrank();
    }

    function testSuccess_skim_type0_skim() public {
        depositERC20InAccount(eth, 2000, accountOwner);

        vm.prank(tokenCreatorAddress);
        eth.mint(address(account_), 1000);

        vm.startPrank(accountOwner);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(account_), accountOwner, 1000);
        account_.skim(address(eth), 0, 0);
        vm.stopPrank();
    }

    function testSuccess_skim_type0_nothingToSkim() public {
        depositERC20InAccount(eth, 2000, accountOwner);

        uint256 balanceBeforeStored = account_.erc20Balances(address(eth));
        uint256 balanceBefore = eth.balanceOf(address(account_));
        assertEq(balanceBeforeStored, balanceBefore);

        vm.startPrank(accountOwner);
        account_.skim(address(eth), 0, 0);
        vm.stopPrank();

        uint256 balancePostStored = account_.erc20Balances(address(eth));
        uint256 balancePost = eth.balanceOf(address(account_));
        assertEq(balancePostStored, balancePost);
        assertEq(balancePostStored, balanceBeforeStored);
    }

    function testSuccess_skim_type1_skim(uint128[] calldata tokenIdsDeposit) public {
        vm.assume(tokenIdsDeposit.length < 15 && tokenIdsDeposit.length > 0);
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            depositBaycInAccount(tokenIdsDeposit, accountOwner);

        address[] memory assetAddrOne = new address[](1);
        uint256[] memory assetIdOne = new uint256[](1);
        uint256[] memory assetAmountOne = new uint256[](1);

        assetAddrOne[0] = assetAddresses[0];
        assetIdOne[0] = assetIds[0];
        assetAmountOne[0] = assetAmounts[0];

        vm.startPrank(accountOwner);
        account_.withdraw(assetAddrOne, assetIdOne, assetAmountOne);
        bayc.transferFrom(accountOwner, address(account_), assetIdOne[0]);

        account_.skim(assetAddrOne[0], assetIdOne[0], 1);
        vm.stopPrank();

        assertEq(bayc.ownerOf(assetIdOne[0]), accountOwner);
    }

    function testSuccess_skim_type1_nothingToSkim() public {
        uint128[] memory tokenIdsDeposit = new uint128[](5);
        tokenIdsDeposit[0] = 100;
        tokenIdsDeposit[1] = 200;
        tokenIdsDeposit[2] = 300;
        tokenIdsDeposit[3] = 400;
        tokenIdsDeposit[4] = 500;
        (address[] memory assetAddresses, uint256[] memory assetIds,) =
            depositBaycInAccount(tokenIdsDeposit, accountOwner);

        uint256 balanceBefore = bayc.balanceOf(address(account_));

        vm.startPrank(accountOwner);
        account_.skim(assetAddresses[0], assetIds[0], 1);
        vm.stopPrank();

        uint256 balancePost = bayc.balanceOf(address(account_));

        assertEq(balanceBefore, balancePost);
        assertEq(bayc.ownerOf(assetIds[0]), address(account_));
    }

    function testSuccess_skim_type2_skim() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10_000;

        vm.prank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);

        assetAmounts[0] = 100;
        vm.startPrank(accountOwner);
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        interleave.safeTransferFrom(accountOwner, address(account_), 1, 100, "");

        uint256 balanceOwnerBefore = interleave.balanceOf(accountOwner, 1);

        account_.skim(address(interleave), 1, 2);
        vm.stopPrank();

        uint256 balanceOwnerAfter = interleave.balanceOf(accountOwner, 1);

        assertEq(interleave.balanceOf(address(account_), 1), account_.erc1155Balances(address(interleave), 1));
        assertEq(balanceOwnerBefore + 100, balanceOwnerAfter);
    }

    function testSuccess_skim_type2_nothingToSkim() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10_000;

        vm.startPrank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);

        uint256 balanceBefore = interleave.balanceOf(address(account_), 1);

        account_.skim(address(interleave), 1, 2);
        vm.stopPrank();

        uint256 balancePost = interleave.balanceOf(address(account_), 1);

        assertEq(balanceBefore, balancePost);
        assertEq(interleave.balanceOf(address(account_), 1), account_.erc1155Balances(address(interleave), 1));
    }

    function testSuccess_skim_ether() public {
        vm.deal(address(account_), 1e21);
        assertEq(address(account_).balance, 1e21);

        uint256 balanceOwnerBefore = accountOwner.balance;

        vm.prank(accountOwner);
        account_.skim(address(0), 0, 0);

        uint256 balanceOwnerAfter = accountOwner.balance;

        assertEq(balanceOwnerBefore + 1e21, balanceOwnerAfter);
    }
}
