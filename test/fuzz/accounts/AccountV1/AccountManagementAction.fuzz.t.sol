/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { AccountExtension, AccountV1 } from "../../../utils/Extensions.sol";
import { ActionData } from "../../../../src/actions/utils/ActionData.sol";
import { ActionMultiCallV2 } from "../../../../src/actions/MultiCallV2.sol";
import { MultiActionMock } from "../../.././utils/mocks/MultiActionMock.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the "accountManagementAction" of contract "AccountV1".
 */
contract AccountManagementAction_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountExtension internal accountNotInitialised;
    ActionMultiCallV2 internal action;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

        // Deploy multicall contract and actions
        action = new ActionMultiCallV2();
        multiActionMock = new MultiActionMock();

        // Set allowed action contract
        vm.prank(users.creatorAddress);
        mainRegistryExtension.setAllowedAction(address(action), true);

        accountNotInitialised = new AccountExtension();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_accountManagementAction_Reentered(
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

    function testFuzz_Revert_accountManagementAction_NonAssetManager(address sender, address assetManager) public {
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

    function testFuzz_Revert_accountManagementAction_OwnerChanged(address assetManager) public {
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

    function testFuzz_Revert_accountManagementAction_actionNotAllowed(address action_) public {
        vm.assume(action_ != address(action));

        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_AMA: Action not allowed");
        accountExtension.accountManagementAction(action_, new bytes(0));
        vm.stopPrank();
    }

    function testFuzz_Revert_accountManagementAction_tooManyAssets(uint8 arrLength) public {
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

    function testFuzz_Revert_accountManagementAction_InsufficientReturned(
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
        accountNotInitialised.setTrustedCreditor(address(trustedCreditor));
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

        trustedCreditor.setOpenPosition(address(accountNotInitialised), debtAmount);

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

    function testFuzz_Success_accountManagementAction_Owner(uint128 debtAmount, uint32 fixedLiquidationCost) public {
        accountNotInitialised.setFixedLiquidationCost(fixedLiquidationCost);
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setRegistry(address(mainRegistryExtension));
        vm.prank(users.accountOwner);
        accountNotInitialised.setBaseCurrency(address(mockERC20.token1));
        accountNotInitialised.setTrustedCreditor(address(trustedCreditor));
        accountNotInitialised.setIsTrustedCreditorSet(true);

        trustedCreditor.setOpenPosition(address(accountNotInitialised), debtAmount);

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

        // Assert the Account has no TOKEN2 and STABLE1 balance initially
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) == 0);
        assert(mockERC20.stable1.balanceOf(address(accountNotInitialised)) == 0);
        // Assert the owner of token id 1 of mockERC721.nft1 contract is accountOwner
        assert(mockERC721.nft1.ownerOf(1) == users.accountOwner);

        // Call accountManagementAction() on Account
        accountNotInitialised.accountManagementAction(address(action), callData);

        // Assert that the Account now has a balance of TOKEN2 and STABLE1
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) > 0);
        assert(mockERC20.stable1.balanceOf(address(accountNotInitialised)) == stable1AmountForAction);
        // Assert that token id 1 of mockERC721.nft1 contract was transferred to the Account
        assert(mockERC721.nft1.ownerOf(1) == address(accountNotInitialised));

        vm.stopPrank();
    }

    function testFuzz_Success_accountManagementAction_AssetManager(
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
        accountNotInitialised.setTrustedCreditor(address(trustedCreditor));
        accountNotInitialised.setIsTrustedCreditorSet(true);
        vm.stopPrank();

        trustedCreditor.setOpenPosition(address(accountNotInitialised), debtAmount);

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
}
