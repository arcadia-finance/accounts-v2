/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { StdStorage, stdStorage } from "../../../lib/forge-std/src/Test.sol";
import { Base_IntegrationAndUnit_Test, Constants } from "../Base_IntegrationAndUnit.t.sol";
import { AccountExtension, AccountV1 } from "../utils/Extensions.sol";
import { MultiActionMock } from "../../mockups/MultiActionMock.sol";
import { ActionMultiCallV2 } from "../../actions/MultiCallV2.sol";
import { ActionData } from "../../actions/utils/ActionData.sol";
import { ERC20Mock } from "../../mockups/ERC20SolmateMock.sol";

contract Account_Integration_Test is Base_IntegrationAndUnit_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccountExtension internal accountNotInitialised;
    AccountExtension internal accountExtension;
    MultiActionMock internal multiActionMock;
    ActionMultiCallV2 internal action;

    /* ///////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function depositERC20InAccount(ERC20Mock token, uint256 amount, address sender, address account_)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(users.tokenCreatorAddress);
        token.mint(sender, amount);

        token.balanceOf(0x0000000000000000000000000000000000000006);

        vm.startPrank(sender);
        token.approve(account_, amount);
        AccountExtension(account_).deposit(assetAddresses, assetIds, assetAmounts);
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
            vm.prank(users.tokenCreatorAddress);
            mockERC721.nft1.mint(users.accountOwner, id);
            assetAddresses[i] = address(mockERC721.nft1);
            assetIds[i] = id;
            assetAmounts[i] = 1;
            assetTypes[i] = 1;
            ++id;
        }
    }

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();

        // Deploy uninitialised account.
        accountNotInitialised = new AccountExtension();

        // Deploy Account.
        accountExtension = new AccountExtension();

        // Initiate Account (set owner and baseCurrency).
        accountExtension.initialize(
            users.accountOwner,
            address(mainRegistryExtension),
            address(mockERC20.stable1),
            address(trustedCreditorWithParamsInit)
        );

        // Set account in factory.
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension))
            .checked_write(true);

        // Initiate Reentrancy guard.
        accountExtension.setLocked(1);

        // Deploy multicall contract and actions
        action = new ActionMultiCallV2();
        multiActionMock = new MultiActionMock();

        // Set allowed action contract
        vm.prank(users.creatorAddress);
        mainRegistryExtension.setAllowedAction(address(action), true);
    }

    /* ///////////////////////////////////////////////////////////////
                          ACCOUNT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testRevert_initialize_InvalidMainreg() public {
        vm.expectRevert("A_I: Registry cannot be 0!");
        accountNotInitialised.initialize(users.accountOwner, address(0), address(0), address(0));
    }

    function testRevert_initialize_AlreadyInitialized() public {
        accountNotInitialised.initialize(users.accountOwner, address(mainRegistryExtension), address(0), address(0));

        vm.expectRevert("A_I: Already initialized!");
        accountNotInitialised.initialize(users.accountOwner, address(mainRegistryExtension), address(0), address(0));
    }

    function test_initialize(address owner_) public {
        vm.expectEmit(true, true, true, true);
        emit BaseCurrencySet(address(0));
        accountNotInitialised.initialize(owner_, address(mainRegistryExtension), address(0), address(0));

        assertEq(accountNotInitialised.owner(), owner_);
        assertEq(accountNotInitialised.getLocked(), 1);
        assertEq(accountNotInitialised.registry(), address(mainRegistryExtension));
        assertEq(accountNotInitialised.baseCurrency(), address(0));
    }

    function testFuzz_Revert_upgradeAccount_Reentered(
        address newImplementation,
        address newRegistry,
        uint16 newVersion,
        bytes calldata data
    ) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(users.accountOwner);
        vm.expectRevert("A: REENTRANCY");
        accountExtension.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_upgradeAccount_NonFactory(
        address newImplementation,
        address newRegistry,
        uint16 newVersion,
        address nonFactory,
        bytes calldata data
    ) public {
        vm.assume(nonFactory != address(factory));

        // Should revert if not called by the Factory.
        vm.startPrank(nonFactory);
        vm.expectRevert("A: Only Factory");
        accountExtension.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_upgradeAccount_InvalidAccountVersion(
        address newImplementation,
        address newRegistry,
        uint16 newVersion,
        bytes calldata data
    ) public {
        // Check in creditor if new version is allowed should fail.
        trustedCreditorWithParamsInit.setCallResult(false);

        vm.startPrank(address(factory));
        vm.expectRevert("A_UA: Invalid Account version");
        accountExtension.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                    MARGIN ACCOUNT SETTINGS
    /////////////////////////////////////////////////////////////// */

    function test_openTrustedMarginAccount() public {
        // Assert no creditor has been set on deployment
        assertEq(AccountV1(deployedAccountInputs0).trustedCreditor(), address(0));
        assertEq(AccountV1(deployedAccountInputs0).isTrustedCreditorSet(), false);
        // Assert no liquidator, baseCurrency and liquidation costs have been defined on deployment
        assertEq(AccountV1(deployedAccountInputs0).liquidator(), address(0));
        assertEq(AccountV1(deployedAccountInputs0).fixedLiquidationCost(), 0);
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), address(0));

        // Open a margin account
        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditorWithParamsInit), Constants.initLiquidator);
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));
        vm.stopPrank();

        // Assert a creditor has been set and other variables updated
        assertEq(AccountV1(deployedAccountInputs0).trustedCreditor(), address(trustedCreditorWithParamsInit));
        assertEq(AccountV1(deployedAccountInputs0).isTrustedCreditorSet(), true);
        assertEq(AccountV1(deployedAccountInputs0).liquidator(), Constants.initLiquidator);
        assertEq(AccountV1(deployedAccountInputs0).fixedLiquidationCost(), Constants.initLiquidationCost);
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), initBaseCurrency);
    }

    function testRevert_openTrustedMarginAccount_NotOwner() public {
        // Should revert if not called by the owner
        vm.expectRevert("A: Only Owner");
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));
    }

    function testRevert_openTrustedMarginAccount_AlreadySet() public {
        // Open a margin account => will set a trusted creditor
        vm.startPrank(users.accountOwner);
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));

        // Should revert if a trusted creditor is already set
        vm.expectRevert("A_OTMA: ALREADY SET");
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));
    }

    function testRevert_openTrustedMarginAccount_InvalidAccountVersion() public {
        // set a different Account version on the trusted creditor
        defaultTrustedCreditor.setCallResult(false);
        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_OTMA: Invalid Version");
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount((address(defaultTrustedCreditor)));
        vm.stopPrank();
    }

    function testFuzz_openTrustedMarginAccount_DifferentBaseCurrency(address liquidator, uint96 fixedLiquidationCost)
        public
    {
        // Confirm initial base currency is not set for the Account
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), address(0));

        // Update base currency of the trusted creditor to TOKEN1
        defaultTrustedCreditor.setBaseCurrency(address(mockERC20.token1));
        // Update liquidation costs in trusted creditor
        defaultTrustedCreditor.setFixedLiquidationCost(fixedLiquidationCost);
        // Update liquidator in trusted creditor
        defaultTrustedCreditor.setLiquidator(liquidator);

        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit BaseCurrencySet(address(mockERC20.token1));
        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(defaultTrustedCreditor), liquidator);
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));
        vm.stopPrank();

        assertEq(AccountV1(deployedAccountInputs0).trustedCreditor(), address(defaultTrustedCreditor));
        assertEq(AccountV1(deployedAccountInputs0).isTrustedCreditorSet(), true);
        assertEq(AccountV1(deployedAccountInputs0).liquidator(), liquidator);
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), address(mockERC20.token1));
        assertEq(AccountV1(deployedAccountInputs0).fixedLiquidationCost(), fixedLiquidationCost);
    }

    function test_openTrustedMarginAccount_SameBaseCurrency() public {
        // Deploy a Account with baseCurrency set to STABLE1
        address deployedAccount = factory.createAccount(1111, 0, address(mockERC20.stable1), address(0));
        assertEq(AccountV1(deployedAccount).baseCurrency(), address(mockERC20.stable1));
        assertEq(trustedCreditorWithParamsInit.baseCurrency(), address(mockERC20.stable1));

        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditorWithParamsInit), Constants.initLiquidator);
        AccountV1(deployedAccount).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));

        assertEq(AccountV1(deployedAccount).liquidator(), Constants.initLiquidator);
        assertEq(AccountV1(deployedAccount).trustedCreditor(), address(trustedCreditorWithParamsInit));
        assertEq(AccountV1(deployedAccount).baseCurrency(), address(mockERC20.stable1));
        assertEq(AccountV1(deployedAccount).fixedLiquidationCost(), Constants.initLiquidationCost);
        assertTrue(AccountV1(deployedAccount).isTrustedCreditorSet());
    }

    /* ///////////////////////////////////////////////////////////////
                        LIQUIDATION LOGIC
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_liquidateAccount_Reentered(uint128 debt) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(users.accountOwner);
        vm.expectRevert("A: REENTRANCY");
        accountExtension.liquidateAccount(debt);
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NotAuthorized(uint128 debt, address unprivilegedAddress) public {
        // msg.sender is different from the Liquidator.
        vm.assume(unprivilegedAddress != accountExtension.liquidator());

        // Should revert if not called by the Liquidator
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("A_LA: Only Liquidator");
        accountExtension.liquidateAccount(debt);
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_AccountIsHealthy(
        uint128 debt,
        uint128 liquidationValue,
        uint96 fixedLiquidationCost
    ) public {
        // Assume account is healthy: liquidationValue is bigger than usedMargin (debt + fixedLiquidationCost).
        uint256 usedMargin = uint256(debt) + fixedLiquidationCost;
        vm.assume(liquidationValue >= usedMargin);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(fixedLiquidationCost);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, liquidationValue);

        // Should revert if account is healthy.
        vm.startPrank(accountExtension.liquidator());
        vm.expectRevert("A_LA: liqValue above usedMargin");
        accountExtension.liquidateAccount(debt);
        vm.stopPrank();
    }

    function testFuzz_liquidateAccount_Unhealthy(uint128 debt, uint128 liquidationValue, uint96 fixedLiquidationCost)
        public
    {
        // Assume account is unhealthy: liquidationValue is smaller than usedMargin (debt + fixedLiquidationCost).
        uint256 usedMargin = uint256(debt) + fixedLiquidationCost;
        vm.assume(liquidationValue < usedMargin);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(fixedLiquidationCost);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, liquidationValue);

        // Should liquidate the Account.
        vm.startPrank(accountExtension.liquidator());
        vm.expectEmit(true, true, true, true);
        emit TrustedMarginAccountChanged(address(0), address(0));
        (address originalOwner, address baseCurrency, address trustedCreditor_) =
            accountExtension.liquidateAccount(debt);
        vm.stopPrank();

        assertEq(originalOwner, users.accountOwner);
        assertEq(baseCurrency, address(mockERC20.stable1));
        assertEq(trustedCreditor_, address(trustedCreditorWithParamsInit));

        assertEq(accountExtension.owner(), Constants.initLiquidator);
        assertEq(accountExtension.isTrustedCreditorSet(), false);
        assertEq(accountExtension.trustedCreditor(), address(0));
        assertEq(accountExtension.fixedLiquidationCost(), 0);
    }

    /*///////////////////////////////////////////////////////////////
                    ASSET MANAGEMENT LOGIC
    ///////////////////////////////////////////////////////////////*/
    function testRevert_Fuzz_accountManagementAction_Reentered(
        address sender,
        address actionHandler,
        bytes calldata actionData
    ) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(sender);
        vm.expectRevert("A: REENTRANCY");
        accountExtension.accountManagementAction(actionHandler, actionData);
        vm.stopPrank();
    }

    function testRevert_Fuzz_accountManagementAction_NonAssetManager(address sender, address assetManager) public {
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != assetManager);
        vm.assume(sender != address(0));

        vm.prank(users.accountOwner);
        accountExtension.setAssetManager(assetManager, true);

        vm.startPrank(sender);
        vm.expectRevert("A: Only Asset Manager");
        accountExtension.accountManagementAction(address(action), new bytes(0));
        vm.stopPrank();
    }

    function testRevert_Fuzz_accountManagementAction_OwnerChanged(address assetManager) public {
        vm.assume(assetManager != address(0));
        address newOwner = address(60); //Annoying to fuzz since it often fuzzes to existing contracts without an onERC721Received
        vm.assume(assetManager != newOwner);

        // Deploy account via factory (proxy)
        vm.startPrank(users.accountOwner);
        address proxyAddr = factory.createAccount(12_345_678, 0, address(0), address(0));
        AccountExtension proxy = AccountExtension(proxyAddr);
        vm.stopPrank();

        vm.prank(users.accountOwner);
        proxy.setAssetManager(assetManager, true);

        vm.prank(users.accountOwner);
        factory.safeTransferFrom(users.accountOwner, newOwner, address(proxy));

        vm.startPrank(assetManager);
        vm.expectRevert("A: Only Asset Manager");
        proxy.accountManagementAction(address(action), new bytes(0));
        vm.stopPrank();
    }

    function testRevert_Fuzz_accountManagementAction_actionNotAllowed(address action_) public {
        vm.assume(action_ != address(action));

        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_AMA: Action not allowed");
        accountExtension.accountManagementAction(action_, new bytes(0));
        vm.stopPrank();
    }

    function testRevert_Fuzz_accountManagementAction_tooManyAssets(uint8 arrLength) public {
        vm.assume(arrLength > accountExtension.ASSET_LIMIT() && arrLength < 50);

        address[] memory assetAddresses = new address[](arrLength);
        uint256[] memory assetIds = new uint256[](arrLength);
        uint256[] memory assetAmounts = new uint256[](arrLength);
        uint256[] memory assetTypes = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts, assetTypes) = generateERC721DepositList(arrLength);

        bytes[] memory data = new bytes[](0);
        address[] memory to = new address[](0);

        ActionData memory assetDataOut;

        ActionData memory transferFromOwner;

        ActionData memory assetDataIn = ActionData({
            assets: assetAddresses,
            assetIds: assetIds,
            assetAmounts: assetAmounts,
            assetTypes: assetTypes,
            actionBalances: new uint256[](0)
        });

        bytes memory callData = abi.encode(assetDataOut, transferFromOwner, assetDataIn, to, data);

        //Already sent asset to action contract
        uint256 id = 10;
        for (uint256 i; i < arrLength; ++i) {
            vm.prank(users.accountOwner);
            mockERC721.nft1.transferFrom(users.accountOwner, address(action), id);
            ++id;
        }
        vm.prank(address(action));
        mockERC721.nft1.setApprovalForAll(address(accountExtension), true);

        vm.prank(users.accountOwner);
        vm.expectRevert("A_D: Too many assets");
        accountExtension.accountManagementAction(address(action), callData);
    }

    function testFuzz_accountManagementAction_Owner(uint128 debtAmount, uint32 fixedLiquidationCost) public {
        accountNotInitialised.setFixedLiquidationCost(fixedLiquidationCost);
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setRegistry(address(mainRegistryExtension));
        vm.prank(users.accountOwner);
        accountNotInitialised.setBaseCurrency(address(mockERC20.token1));
        accountNotInitialised.setTrustedCreditor(address(trustedCreditorWithParamsInit));
        accountNotInitialised.setIsTrustedCreditorSet(true);

        trustedCreditorWithParamsInit.setOpenPosition(address(accountNotInitialised), debtAmount);

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);

        uint256 token1AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 stable1AmountForAction = 500 * 10 ** Constants.stableDecimals;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        vm.assume(
            token1AmountForAction + ((uint256(debtAmount) + fixedLiquidationCost) * token1ToToken2Ratio)
                < type(uint256).max
        );

        // We increase the price of token 2 in order to avoid to end up with unhealthy state of account
        vm.startPrank(users.defaultTransmitter);
        mockOracles.token2ToUsd.transmit(int256(1000 * 10 ** Constants.tokenOracleDecimals));
        vm.stopPrank();

        bytes[] memory data = new bytes[](5);
        address[] memory to = new address[](5);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(multiActionMock), token1AmountForAction + uint256(debtAmount)
        );
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(mockERC20.token1),
            address(mockERC20.token2),
            token1AmountForAction + uint256(debtAmount),
            token2AmountForAction + uint256(debtAmount) * token1ToToken2Ratio
        );
        data[2] = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(accountNotInitialised),
            token2AmountForAction + uint256(debtAmount) * token1ToToken2Ratio
        );
        data[3] =
            abi.encodeWithSignature("approve(address,uint256)", address(accountNotInitialised), stable1AmountForAction);
        data[4] = abi.encodeWithSignature("approve(address,uint256)", address(accountNotInitialised), 1);

        vm.prank(users.tokenCreatorAddress);
        mockERC20.token2.mint(address(multiActionMock), token2AmountForAction + debtAmount * token1ToToken2Ratio);

        vm.prank(users.tokenCreatorAddress);
        mockERC20.token1.mint(address(action), debtAmount);

        to[0] = address(mockERC20.token1);
        to[1] = address(multiActionMock);
        to[2] = address(mockERC20.token2);
        to[3] = address(mockERC20.stable1);
        to[4] = address(mockERC721.nft1);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(mockERC20.token1);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = token1AmountForAction;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](3),
            assetIds: new uint256[](3),
            assetAmounts: new uint256[](3),
            assetTypes: new uint256[](3),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(mockERC20.token2);
        // Add stable 1 that will be sent from owner wallet to action contract
        assetDataIn.assets[1] = address(mockERC20.stable1);
        // Add nft1 that will be sent from owner wallet to action contract
        assetDataIn.assets[2] = address(mockERC721.nft1);
        assetDataIn.assetTypes[0] = 0;
        assetDataIn.assetTypes[1] = 0;
        assetDataIn.assetTypes[2] = 1;
        assetDataIn.assetIds[0] = 0;
        assetDataIn.assetIds[1] = 0;
        assetDataIn.assetIds[2] = 1;

        ActionData memory transferFromOwner = ActionData({
            assets: new address[](2),
            assetIds: new uint256[](2),
            assetAmounts: new uint256[](2),
            assetTypes: new uint256[](2),
            actionBalances: new uint256[](0)
        });

        transferFromOwner.assets[0] = address(mockERC20.stable1);
        transferFromOwner.assets[1] = address(mockERC721.nft1);
        transferFromOwner.assetAmounts[0] = stable1AmountForAction;
        transferFromOwner.assetAmounts[1] = 1;
        transferFromOwner.assetTypes[0] = 0;
        transferFromOwner.assetTypes[1] = 1;
        transferFromOwner.assetIds[0] = 0;
        transferFromOwner.assetIds[1] = 1;

        bytes memory callData = abi.encode(assetDataOut, transferFromOwner, assetDataIn, to, data);

        // Deposit token1 in account first
        depositERC20InAccount(
            mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountNotInitialised)
        );

        vm.startPrank(users.accountOwner);
        deal(address(mockERC20.stable1), users.accountOwner, stable1AmountForAction);
        mockERC721.nft1.mint(users.accountOwner, 1);
        // Approve the "stable1" and "nft1" tokens that will need to be transferred from owner to action contract
        mockERC20.stable1.approve(address(accountNotInitialised), stable1AmountForAction);
        mockERC721.nft1.approve(address(accountNotInitialised), 1);

        // Assert the account has no TOKEN2 and STABLE1 balance initially
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) == 0);
        assert(mockERC20.stable1.balanceOf(address(accountNotInitialised)) == 0);

        // Call accountManagementAction() on Account
        accountNotInitialised.accountManagementAction(address(action), callData);

        // Assert that the Account now has a balance of TOKEN2 and STABLE1
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) > 0);
        assert(mockERC20.stable1.balanceOf(address(accountNotInitialised)) == stable1AmountForAction);

        vm.stopPrank();
    }

    function testFuzz_accountManagementAction_AssetManager(
        uint128 debtAmount,
        uint32 fixedLiquidationCost,
        address assetManager
    ) public {
        vm.assume(users.accountOwner != assetManager);
        vm.startPrank(users.accountOwner);
        accountNotInitialised.setFixedLiquidationCost(fixedLiquidationCost);
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setAssetManager(assetManager, true);
        accountNotInitialised.setRegistry(address(mainRegistryExtension));
        accountNotInitialised.setBaseCurrency(address(mockERC20.token1));
        accountNotInitialised.setTrustedCreditor(address(trustedCreditorWithParamsInit));
        accountNotInitialised.setIsTrustedCreditorSet(true);
        vm.stopPrank();

        trustedCreditorWithParamsInit.setOpenPosition(address(accountNotInitialised), debtAmount);

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);

        uint256 token1AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        vm.assume(
            token1AmountForAction + ((uint256(debtAmount) + fixedLiquidationCost) * token1ToToken2Ratio)
                < type(uint256).max
        );

        // We increase the price of token 2 in order to avoid to end up with unhealthy state of account
        vm.startPrank(users.defaultTransmitter);
        mockOracles.token2ToUsd.transmit(int256(1000 * 10 ** Constants.tokenOracleDecimals));
        vm.stopPrank();

        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(multiActionMock), token1AmountForAction + uint256(debtAmount)
        );
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(mockERC20.token1),
            address(mockERC20.token2),
            token1AmountForAction + uint256(debtAmount),
            token2AmountForAction + uint256(debtAmount) * token1ToToken2Ratio
        );
        data[2] = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(accountNotInitialised),
            token2AmountForAction + uint256(debtAmount) * token1ToToken2Ratio
        );

        vm.prank(users.tokenCreatorAddress);
        mockERC20.token2.mint(address(multiActionMock), token2AmountForAction + debtAmount * token1ToToken2Ratio);

        vm.prank(users.tokenCreatorAddress);
        mockERC20.token1.mint(address(action), debtAmount);

        to[0] = address(mockERC20.token1);
        to[1] = address(multiActionMock);
        to[2] = address(mockERC20.token2);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(mockERC20.token1);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = token1AmountForAction;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(mockERC20.token2);
        assetDataIn.assetTypes[0] = 0;
        assetDataIn.assetIds[0] = 0;

        ActionData memory transferFromOwner;

        bytes memory callData = abi.encode(assetDataOut, transferFromOwner, assetDataIn, to, data);

        // Deposit token1 in account first
        depositERC20InAccount(
            mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountNotInitialised)
        );

        vm.startPrank(assetManager);

        // Assert the account has no TOKEN2 balance initially
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) == 0);

        // Call accountManagementAction() on Account
        accountNotInitialised.accountManagementAction(address(action), callData);

        // Assert that the Account now has a balance of TOKEN2
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) > 0);

        vm.stopPrank();
    }

    function testRevert_Fuzz_accountManagementAction_InsufficientReturned(
        uint128 debtAmount,
        uint32 fixedLiquidationCost
    ) public {
        vm.assume(debtAmount > 0);

        // Init account
        vm.startPrank(users.accountOwner);
        accountNotInitialised.setFixedLiquidationCost(fixedLiquidationCost);
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setRegistry(address(mainRegistryExtension));
        accountNotInitialised.setBaseCurrency(address(mockERC20.token1));
        accountNotInitialised.setTrustedCreditor(address(trustedCreditorWithParamsInit));
        accountNotInitialised.setIsTrustedCreditorSet(true);
        vm.stopPrank();

        accountNotInitialised.setFixedLiquidationCost(fixedLiquidationCost);

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);

        uint256 token1AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        vm.assume(
            token1AmountForAction + ((uint256(debtAmount) + fixedLiquidationCost) * token1ToToken2Ratio)
                < type(uint256).max
        );

        trustedCreditorWithParamsInit.setOpenPosition(address(accountNotInitialised), debtAmount);

        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(multiActionMock), token1AmountForAction + uint256(debtAmount)
        );
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(mockERC20.token1),
            address(mockERC20.token2),
            token1AmountForAction + uint256(debtAmount),
            0
        );
        data[2] = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(accountNotInitialised),
            token2AmountForAction + uint256(debtAmount) * token1ToToken2Ratio
        );

        vm.prank(users.tokenCreatorAddress);
        mockERC20.token1.mint(address(action), debtAmount);

        to[0] = address(mockERC20.token1);
        to[1] = address(multiActionMock);
        to[2] = address(mockERC20.token2);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(mockERC20.token1);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = token1AmountForAction;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(mockERC20.token2);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        ActionData memory transferFromOwner;

        bytes memory callData = abi.encode(assetDataOut, transferFromOwner, assetDataIn, to, data);

        // Deposit token1 in account first
        depositERC20InAccount(
            mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountNotInitialised)
        );

        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_AMA: Account Unhealthy");
        accountNotInitialised.accountManagementAction(address(action), callData);
        vm.stopPrank();
    }
}
