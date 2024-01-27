/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Constants, AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

import { AccountExtension, AccountV1 } from "../../../utils/Extensions.sol";
import { IActionBase, ActionData } from "../../../../src/interfaces/IActionBase.sol";
import { ActionMultiCall } from "../../../../src/actions/MultiCall.sol";
import { MultiActionMock } from "../../.././utils/mocks/actions/MultiActionMock.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { IPermit2 } from "../../../utils/Interfaces.sol";
import { Utils } from "../../../utils/Utils.sol";
import { Permit2Fixture } from "../../../utils/fixtures/permit2/Permit2Fixture.f.sol";

/**
 * @notice Fuzz tests for the function "flashAction" of contract "AccountV1".
 */
contract FlashAction_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test, Permit2Fixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountExtension internal accountNotInitialised;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountV1_Fuzz_Test, Permit2Fixture) {
        AccountV1_Fuzz_Test.setUp();
        Permit2Fixture.setUp();

        // Deploy multicall contract and actions
        action = new ActionMultiCall();
        multiActionMock = new MultiActionMock();

        accountNotInitialised = new AccountExtension(address(factory));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_flashAction_NonAssetManager(address sender, address assetManager)
        public
        notTestContracts(sender)
    {
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != assetManager);
        vm.assume(sender != address(0));

        vm.prank(users.accountOwner);
        accountExtension.setAssetManager(assetManager, true);

        vm.startPrank(sender);
        vm.expectRevert("A: Only Asset Manager");
        accountExtension.flashAction(address(action), new bytes(0));
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_OwnerChanged(address assetManager) public {
        vm.assume(assetManager != address(0));
        address newOwner = address(60); //Annoying to fuzz since it often fuzzes to existing contracts without an onERC721Received
        vm.assume(assetManager != newOwner);

        // Warp time to avoid CoolDownPeriodNotPassed error on transfer ownership.
        vm.warp(1 days);

        // Deploy account via factory (proxy)
        vm.startPrank(users.accountOwner);
        address proxyAddr = factory.createAccount(12_345_678, 0, address(0));
        AccountExtension proxy = AccountExtension(proxyAddr);
        vm.stopPrank();

        vm.prank(users.accountOwner);
        proxy.setAssetManager(assetManager, true);

        vm.prank(users.accountOwner);
        factory.safeTransferFrom(users.accountOwner, newOwner, address(proxy));

        vm.startPrank(assetManager);
        vm.expectRevert("A: Only Asset Manager");
        proxy.flashAction(address(action), new bytes(0));
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_Reentered(address actionTarget, bytes calldata actionData) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountExtension.flashAction(actionTarget, actionData);
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_InAuction(address actionTarget, bytes calldata actionData) public {
        // Will set "inAuction" to true.
        accountExtension.setInAuction();

        // Should revert if the Account is in an auction.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountInAuction.selector);
        accountExtension.flashAction(actionTarget, actionData);
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_tooManyAssets(uint8 arrLength, bytes calldata signature) public {
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
            assetTypes: assetTypes
        });

        // Avoid stack too deep
        uint8 lengthStack = arrLength;
        bytes calldata signatureStack = signature;

        IPermit2.TokenPermissions[] memory tokenPermissions;

        bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
        bytes memory callData =
            abi.encode(assetDataOut, transferFromOwner, tokenPermissions, signatureStack, actionTargetData);

        //Already sent asset to action contract
        uint256 id = 10;
        for (uint256 i; i < lengthStack; ++i) {
            vm.prank(users.accountOwner);
            mockERC721.nft1.transferFrom(users.accountOwner, address(action), id);
            ++id;
        }

        vm.prank(address(action));
        mockERC721.nft1.setApprovalForAll(address(accountExtension), true);

        vm.prank(users.accountOwner);
        vm.expectRevert(AccountErrors.TooManyAssets.selector);
        accountExtension.flashAction(address(action), callData);
    }

    function testFuzz_Revert_flashAction_InsufficientReturned(
        uint128 debtAmount,
        uint32 minimumMargin,
        bytes calldata signature
    ) public {
        vm.assume(debtAmount > 0);

        // Init account
        vm.startPrank(users.accountOwner);
        accountNotInitialised.setMinimumMargin(minimumMargin);
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setRegistry(address(registryExtension));
        accountNotInitialised.setNumeraire(address(mockERC20.token1));
        accountNotInitialised.setCreditor(address(creditorStable1));
        vm.stopPrank();

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);

        uint256 token1AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        vm.assume(
            token1AmountForAction + ((uint256(debtAmount) + minimumMargin) * token1ToToken2Ratio) < type(uint256).max
        );

        creditorStable1.setOpenPosition(address(accountNotInitialised), debtAmount);

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
            assetTypes: new uint256[](1)
        });

        assetDataOut.assets[0] = address(mockERC20.token1);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = token1AmountForAction;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1)
        });

        assetDataIn.assets[0] = address(mockERC20.token2);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        ActionData memory transferFromOwner;
        IPermit2.TokenPermissions[] memory tokenPermissions;

        // Avoid stack too deep
        bytes memory signatureStack = signature;

        bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
        bytes memory callData =
            abi.encode(assetDataOut, transferFromOwner, tokenPermissions, signatureStack, actionTargetData);

        // Deposit token1 in account first
        depositERC20InAccount(
            mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountNotInitialised)
        );

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        accountNotInitialised.flashAction(address(action), callData);
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_permit2_maliciousSpender(
        uint256 fromPrivateKey,
        uint256 token1Amount,
        uint256 stable1Amount,
        uint256 nonce,
        address maliciousActor
    ) public {
        // Given : Malicious actor is not the spender
        vm.assume(maliciousActor != address(accountNotInitialised));

        // Private key must be less than the secp256k1 curve order and != 0
        fromPrivateKey = bound(
            fromPrivateKey,
            1,
            115_792_089_237_316_195_423_570_985_008_687_907_852_837_564_279_074_904_382_605_163_141_518_161_494_337 - 1
        );
        address from = vm.addr(fromPrivateKey);

        // Initialize Account params
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(from);
        accountNotInitialised.setRegistry(address(registryExtension));
        vm.prank(from);
        accountNotInitialised.setNumeraire(address(mockERC20.token1));
        accountNotInitialised.setCreditor(address(creditorStable1));

        // Set the account as initialized in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = token1Amount;
        amounts[1] = stable1Amount;

        address[] memory tokens = new address[](2);
        tokens[0] = address(mockERC20.token1);
        tokens[1] = address(mockERC20.stable1);

        // Mint tokens and give unlimited approval on the Permit2 contract
        vm.startPrank(users.tokenCreatorAddress);
        mockERC20.token1.mint(from, token1Amount);
        mockERC20.stable1.mint(from, stable1Amount);
        vm.stopPrank();

        vm.startPrank(from);
        mockERC20.token1.approve(address(permit2), type(uint256).max);
        mockERC20.stable1.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        uint256 deadline = block.timestamp;

        bytes32 DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

        // Bring back variables to the stack to avoid stack too deep
        uint256 nonceStack = nonce;
        uint256 fromPrivateKeyStack = fromPrivateKey;
        uint256 token1AmountStack = token1Amount;
        uint256 stable1AmountStack = stable1Amount;
        address maliciousStack = maliciousActor;
        address fromStack = from;

        // Generate struct PermitBatchTransferFrom
        IPermit2.PermitBatchTransferFrom memory permit =
            Utils.defaultERC20PermitMultiple(tokens, amounts, nonceStack, deadline);

        // Get signature
        vm.prank(fromStack);
        bytes memory signature = Utils.getPermitBatchTransferSignature(
            permit, fromPrivateKeyStack, DOMAIN_SEPARATOR, address(accountNotInitialised)
        );

        IPermit2.SignatureTransferDetails[] memory transferDetails = new IPermit2.SignatureTransferDetails[](2);
        transferDetails[0] =
            IPermit2.SignatureTransferDetails({ to: address(action), requestedAmount: token1AmountStack });
        transferDetails[1] =
            IPermit2.SignatureTransferDetails({ to: address(action), requestedAmount: stable1AmountStack });

        vm.startPrank(maliciousStack);
        // The following call should revert as the caller is not the spender.
        vm.expectRevert();
        permit2.permitTransferFrom(permit, transferDetails, fromStack, signature);
    }

    function testFuzz_Success_flashAction_Owner(
        uint128 debtAmount,
        uint32 minimumMargin,
        uint32 time,
        bytes calldata signature
    ) public {
        vm.assume(time > 2 days);
        vm.assume(time > 2 days);
        accountNotInitialised.setMinimumMargin(minimumMargin);
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setRegistry(address(registryExtension));
        vm.prank(users.accountOwner);
        accountNotInitialised.setNumeraire(address(mockERC20.token1));
        accountNotInitialised.setCreditor(address(creditorStable1));

        creditorStable1.setOpenPosition(address(accountNotInitialised), debtAmount);

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);

        uint256 token1AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 stable1AmountForAction = 500 * 10 ** Constants.stableDecimals;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        vm.assume(
            token1AmountForAction + ((uint256(debtAmount) + minimumMargin) * token1ToToken2Ratio) < type(uint256).max
        );

        // We increase the price of token 2 in order to avoid to end up with unhealthy state of account
        vm.startPrank(users.defaultTransmitter);
        mockOracles.token2ToUsd.transmit(int256(1000 * 10 ** Constants.tokenOracleDecimals));
        vm.stopPrank();

        bytes memory callData;
        {
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
            data[3] = abi.encodeWithSignature(
                "approve(address,uint256)", address(accountNotInitialised), stable1AmountForAction
            );
            data[4] = abi.encodeWithSignature("approve(address,uint256)", address(accountNotInitialised), 1);

            // exposure token 2 does not exceed maxExposure.
            vm.assume(token2AmountForAction + debtAmount * token1ToToken2Ratio <= type(uint112).max);
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
                assetTypes: new uint256[](1)
            });

            assetDataOut.assets[0] = address(mockERC20.token1);
            assetDataOut.assetTypes[0] = 0;
            assetDataOut.assetIds[0] = 0;
            assetDataOut.assetAmounts[0] = token1AmountForAction;

            ActionData memory assetDataIn = ActionData({
                assets: new address[](3),
                assetIds: new uint256[](3),
                assetAmounts: new uint256[](3),
                assetTypes: new uint256[](3)
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
            assetDataIn.assetAmounts[2] = 1;

            ActionData memory transferFromOwner = ActionData({
                assets: new address[](2),
                assetIds: new uint256[](2),
                assetAmounts: new uint256[](2),
                assetTypes: new uint256[](2)
            });

            transferFromOwner.assets[0] = address(mockERC20.stable1);
            transferFromOwner.assets[1] = address(mockERC721.nft1);
            transferFromOwner.assetAmounts[0] = stable1AmountForAction;
            transferFromOwner.assetAmounts[1] = 1;
            transferFromOwner.assetTypes[0] = 0;
            transferFromOwner.assetTypes[1] = 1;
            transferFromOwner.assetIds[0] = 0;
            transferFromOwner.assetIds[1] = 1;

            IPermit2.TokenPermissions[] memory tokenPermissions;

            callData = abi.encode(
                assetDataOut, transferFromOwner, tokenPermissions, signature, abi.encode(assetDataIn, to, data)
            );
        }

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
        vm.stopPrank();

        // Assert the Account has no TOKEN2 and STABLE1 balance initially
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) == 0);
        assert(mockERC20.stable1.balanceOf(address(accountNotInitialised)) == 0);
        // Assert the owner of token id 1 of mockERC721.nft1 contract is accountOwner
        assert(mockERC721.nft1.ownerOf(1) == users.accountOwner);

        vm.warp(time);

        // We transmit prices to oracles in order to have the oracles active
        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd));
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));
        mockOracles.nft1ToToken1.transmit(int256(rates.nft1ToToken1));
        // We increase the price of token 2 in order to avoid to end up with unhealthy state of account
        mockOracles.token2ToUsd.transmit(int256(1000 * 10 ** Constants.tokenOracleDecimals));
        vm.stopPrank();

        // Call flashAction() on Account
        vm.prank(users.accountOwner);
        accountNotInitialised.flashAction(address(action), callData);

        // Assert that the Account now has a balance of TOKEN2 and STABLE1
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) > 0);
        assert(mockERC20.stable1.balanceOf(address(accountNotInitialised)) == stable1AmountForAction);
        // Assert that token id 1 of mockERC721.nft1 contract was transferred to the Account
        assert(mockERC721.nft1.ownerOf(1) == address(accountNotInitialised));

        // And: lastActionTimestamp is updated.
        assertEq(accountNotInitialised.lastActionTimestamp(), time);
    }

    function testFuzz_Success_flashActionByAssetManager_AssetManager(
        uint128 debtAmount,
        uint32 minimumMargin,
        address assetManager,
        uint32 time,
        bytes calldata signature
    ) public {
        vm.assume(time > 2 days);
        vm.assume(users.accountOwner != assetManager);
        vm.startPrank(users.accountOwner);
        accountNotInitialised.setMinimumMargin(minimumMargin);
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setAssetManager(assetManager, true);
        accountNotInitialised.setRegistry(address(registryExtension));
        accountNotInitialised.setNumeraire(address(mockERC20.token1));
        accountNotInitialised.setCreditor(address(creditorStable1));
        vm.stopPrank();

        creditorStable1.setOpenPosition(address(accountNotInitialised), debtAmount);

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);

        uint256 token1AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        vm.assume(
            token1AmountForAction + ((uint256(debtAmount) + minimumMargin) * token1ToToken2Ratio) < type(uint256).max
        );

        bytes memory callData;
        {
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

            // exposure token 2 does not exceed maxExposure.
            vm.assume(token2AmountForAction + debtAmount * token1ToToken2Ratio <= type(uint112).max);
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
                assetTypes: new uint256[](1)
            });

            assetDataOut.assets[0] = address(mockERC20.token1);
            assetDataOut.assetTypes[0] = 0;
            assetDataOut.assetIds[0] = 0;
            assetDataOut.assetAmounts[0] = token1AmountForAction;

            ActionData memory assetDataIn = ActionData({
                assets: new address[](1),
                assetIds: new uint256[](1),
                assetAmounts: new uint256[](1),
                assetTypes: new uint256[](1)
            });

            assetDataIn.assets[0] = address(mockERC20.token2);
            assetDataIn.assetTypes[0] = 0;
            assetDataIn.assetIds[0] = 0;

            ActionData memory transferFromOwner;
            IPermit2.TokenPermissions[] memory tokenPermissions;

            callData = abi.encode(
                assetDataOut, transferFromOwner, tokenPermissions, signature, abi.encode(assetDataIn, to, data)
            );
        }

        vm.warp(time);

        // Deposit token1 in account first
        depositERC20InAccount(
            mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountNotInitialised)
        );

        vm.startPrank(users.defaultTransmitter);
        // We increase the price of token 2 in order to avoid to end up with unhealthy state of account
        mockOracles.token2ToUsd.transmit(int256(1000 * 10 ** Constants.tokenOracleDecimals));
        // We transmit price to token 1 oracle in order to have the oracle active
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd));
        vm.stopPrank();

        vm.startPrank(assetManager);

        // Assert the account has no TOKEN2 balance initially
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) == 0);

        // Call flashAction() on Account
        accountNotInitialised.flashAction(address(action), callData);

        // Assert that the Account now has a balance of TOKEN2
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) > 0);

        vm.stopPrank();

        // And: lastActionTimestamp is updated.
        assertEq(accountNotInitialised.lastActionTimestamp(), time);
    }

    function testFuzz_Success_flashAction_permit2(
        uint256 fromPrivateKey,
        uint256 token1Amount,
        uint256 stable1Amount,
        uint256 nonce
    ) public {
        // Private key must be less than the secp256k1 curve order and != 0
        fromPrivateKey = bound(
            fromPrivateKey,
            1,
            115_792_089_237_316_195_423_570_985_008_687_907_852_837_564_279_074_904_382_605_163_141_518_161_494_337 - 1
        );
        address from = vm.addr(fromPrivateKey);

        // Initialize Account params
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(from);
        accountNotInitialised.setRegistry(address(registryExtension));
        vm.prank(from);
        accountNotInitialised.setNumeraire(address(mockERC20.token1));
        accountNotInitialised.setCreditor(address(creditorStable1));

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = token1Amount;
        amounts[1] = stable1Amount;

        address[] memory tokens = new address[](2);
        tokens[0] = address(mockERC20.token1);
        tokens[1] = address(mockERC20.stable1);

        // Mint tokens and give unlimited approval on the Permit2 contract
        vm.startPrank(users.tokenCreatorAddress);
        mockERC20.token1.mint(from, token1Amount);
        mockERC20.stable1.mint(from, stable1Amount);
        vm.stopPrank();

        vm.startPrank(from);
        mockERC20.token1.approve(address(permit2), type(uint256).max);
        mockERC20.stable1.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        bytes memory callData;
        {
            uint256 deadline = block.timestamp;

            // Generate struct PermitBatchTransferFrom
            IPermit2.PermitBatchTransferFrom memory permit =
                Utils.defaultERC20PermitMultiple(tokens, amounts, nonce, deadline);

            bytes32 DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

            // Get signature
            vm.prank(from);
            bytes memory signature = Utils.getPermitBatchTransferSignature(
                permit, fromPrivateKey, DOMAIN_SEPARATOR, address(accountNotInitialised)
            );

            ActionData memory assetDataOut;
            ActionData memory transferFromOwner;
            ActionData memory assetDataIn;
            address[] memory to;
            bytes[] memory data;

            bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
            callData = abi.encode(assetDataOut, transferFromOwner, permit, signature, actionTargetData);
        }

        // Check state pre function call
        assertEq(mockERC20.token1.balanceOf(from), token1Amount);
        assertEq(mockERC20.stable1.balanceOf(from), stable1Amount);
        assertEq(mockERC20.token1.balanceOf(address(action)), 0);
        assertEq(mockERC20.stable1.balanceOf(address(action)), 0);

        // Call flashAction() on Account
        vm.prank(from);
        accountNotInitialised.flashAction(address(action), callData);

        // Check state after function call
        assertEq(mockERC20.token1.balanceOf(from), 0);
        assertEq(mockERC20.stable1.balanceOf(from), 0);
        assertEq(mockERC20.token1.balanceOf(address(action)), token1Amount);
        assertEq(mockERC20.stable1.balanceOf(address(action)), stable1Amount);
    }
}
