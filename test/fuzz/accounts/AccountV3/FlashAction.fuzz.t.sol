/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV3 } from "../../../../src/accounts/AccountV3.sol";
import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";
import { AccountV3Extension } from "../../../utils/extensions/AccountV3Extension.sol";
import { ActionData } from "../../../../src/interfaces/IActionBase.sol";
import { ActionTargetMock } from "../../../utils/mocks/action-targets/ActionTargetMock.sol";
import { Constants } from "../../../utils/Constants.sol";
import { IPermit2 } from "../../../utils/interfaces/IPermit2.sol";
import { RouterMock } from "../../../utils/mocks/action-targets/RouterMock.sol";
import { Permit2Fixture } from "../../../utils/fixtures/permit2/Permit2Fixture.f.sol";
import { SignatureVerification } from "../../../../lib/v4-periphery/lib/permit2/src/libraries/SignatureVerification.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "flashAction" of contract "AccountV3".
 */
contract FlashAction_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test, Permit2Fixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountV3Extension internal accountNotInitialised;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountV3_Fuzz_Test, Permit2Fixture) {
        AccountV3_Fuzz_Test.setUp();
        Permit2Fixture.setUp();

        // Deploy multicall contract and actions
        actionTarget = new ActionTargetMock();
        routerMock = new RouterMock();

        accountNotInitialised = new AccountV3Extension(address(factory), address(accountsGuard), address(0));
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_flashAction_NonAssetManager(address sender, address assetManager)
        public
        canReceiveERC721(sender)
    {
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != assetManager);
        vm.assume(sender != address(0));

        vm.prank(users.accountOwner);
        accountExtension.setAssetManager(assetManager, true);

        vm.startPrank(sender);
        vm.expectRevert("A: Only Asset Manager");
        accountExtension.flashAction(address(actionTarget), new bytes(0));
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_OwnerChanged(address assetManager) public {
        vm.assume(assetManager != address(0));
        address newOwner = address(60); //Annoying to fuzz since it often fuzzes to existing contracts without an onERC721Received
        vm.assume(assetManager != newOwner);

        // Deploy account via factory (proxy)
        vm.startPrank(users.accountOwner);
        address proxyAddr = factory.createAccount(12_345_678, 0, address(0));
        AccountV3Extension proxy = AccountV3Extension(proxyAddr);
        vm.stopPrank();

        address[] memory assetManagers = new address[](1);
        assetManagers[0] = address(assetManager);
        bool[] memory statuses = new bool[](1);
        statuses[0] = true;
        vm.prank(users.accountOwner);
        proxy.setAssetManagers(assetManagers, statuses, new bytes[](1));

        // Warp time to avoid CoolDownPeriodNotPassed error on transfer ownership.
        vm.warp(block.timestamp + 1 days);

        vm.prank(users.accountOwner);
        factory.safeTransferFrom(users.accountOwner, newOwner, address(proxy));

        vm.startPrank(assetManager);
        vm.expectRevert("A: Only Asset Manager");
        proxy.flashAction(address(actionTarget), new bytes(0));
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_Reentered(address actionTarget, bytes calldata actionData) public {
        // Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountsGuard.Reentered.selector);
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

        (assetAddresses, assetIds, assetAmounts, assetTypes) = generateErc721DepositList(arrLength);

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

        //Already sent asset to actionTarget contract
        uint256 id = 10;
        for (uint256 i; i < lengthStack; ++i) {
            vm.prank(users.accountOwner);
            /// forge-lint: disable-next-line(erc20-unchecked-transfer)
            mockERC721.nft1.transferFrom(users.accountOwner, address(actionTarget), id);
            ++id;
        }

        vm.prank(address(actionTarget));
        mockERC721.nft1.setApprovalForAll(address(accountExtension), true);

        vm.prank(users.accountOwner);
        vm.expectRevert(AccountErrors.TooManyAssets.selector);
        accountExtension.flashAction(address(actionTarget), callData);
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
        accountNotInitialised.setRegistry(address(registry));
        accountNotInitialised.setNumeraire(address(mockERC20.token1));
        accountNotInitialised.setCreditor(address(creditorStable1));
        vm.stopPrank();

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);

        uint256 token1AmountForAction = 1000 * 10 ** Constants.TOKEN_DECIMALS;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.TOKEN_DECIMALS;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        vm.assume(
            token1AmountForAction + ((uint256(debtAmount) + minimumMargin) * token1ToToken2Ratio) < type(uint256).max
        );

        creditorStable1.setOpenPosition(address(accountNotInitialised), debtAmount);

        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(routerMock), token1AmountForAction + uint256(debtAmount)
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

        vm.prank(users.tokenCreator);
        mockERC20.token1.mint(address(actionTarget), debtAmount);

        to[0] = address(mockERC20.token1);
        to[1] = address(routerMock);
        to[2] = address(mockERC20.token2);

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1)
        });

        assetDataOut.assets[0] = address(mockERC20.token1);
        assetDataOut.assetTypes[0] = 1;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = token1AmountForAction;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1)
        });

        assetDataIn.assets[0] = address(mockERC20.token2);
        assetDataOut.assetTypes[0] = 1;
        assetDataOut.assetIds[0] = 0;

        ActionData memory transferFromOwner;
        IPermit2.TokenPermissions[] memory tokenPermissions;

        // Avoid stack too deep
        bytes memory signatureStack = signature;

        bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
        bytes memory callData =
            abi.encode(assetDataOut, transferFromOwner, tokenPermissions, signatureStack, actionTargetData);

        // Deposit token1 in account first
        depositErc20InAccount(
            mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountNotInitialised)
        );

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        accountNotInitialised.flashAction(address(actionTarget), callData);
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_permit2_InvalidSignatureLength(
        uint256 token1Amount,
        uint256 stable1Amount,
        uint256 nonce,
        bytes calldata invalidSignature
    ) public {
        vm.assume(invalidSignature.length != 65 && invalidSignature.length != 64);

        // Initialize Account params
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setRegistry(address(registry));
        vm.prank(users.accountOwner);
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
        vm.startPrank(users.tokenCreator);
        mockERC20.token1.mint(users.accountOwner, token1Amount);
        mockERC20.stable1.mint(users.accountOwner, stable1Amount);
        vm.stopPrank();

        vm.startPrank(users.accountOwner);
        mockERC20.token1.approve(address(permit2), type(uint256).max);
        mockERC20.stable1.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        bytes memory callData;
        {
            uint256 deadline = block.timestamp;

            // Generate struct PermitBatchTransferFrom
            IPermit2.PermitBatchTransferFrom memory permit =
                Utils.defaultERC20PermitMultiple(tokens, amounts, nonce, deadline);

            // Get signature
            ActionData memory emptyData;
            address[] memory to;
            bytes[] memory data;

            bytes memory actionTargetData = abi.encode(emptyData, to, data);
            callData = abi.encode(emptyData, emptyData, permit, invalidSignature, actionTargetData);
        }

        // Call flashAction() on Account
        vm.prank(users.accountOwner);
        vm.expectRevert(SignatureVerification.InvalidSignatureLength.selector);
        accountNotInitialised.flashAction(address(actionTarget), callData);
    }

    function testFuzz_Revert_flashAction_permit2_InvalidSignature(
        uint256 token1Amount,
        uint256 stable1Amount,
        uint256 nonce,
        bytes32 r,
        bytes32 s,
        bytes1 invalidV
    ) public {
        vm.assume(invalidV != bytes1(uint8(27)) && invalidV != bytes1(uint8(28)));

        // Initialize Account params
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setRegistry(address(registry));
        vm.prank(users.accountOwner);
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
        vm.startPrank(users.tokenCreator);
        mockERC20.token1.mint(users.accountOwner, token1Amount);
        mockERC20.stable1.mint(users.accountOwner, stable1Amount);
        vm.stopPrank();

        vm.startPrank(users.accountOwner);
        mockERC20.token1.approve(address(permit2), type(uint256).max);
        mockERC20.stable1.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        bytes memory callData;
        {
            // Generate struct PermitBatchTransferFrom
            IPermit2.PermitBatchTransferFrom memory permit =
                Utils.defaultERC20PermitMultiple(tokens, amounts, nonce, block.timestamp);

            // Get signature
            bytes memory signature = new bytes(65);
            assembly {
                mstore(add(signature, 32), r)
                mstore(add(signature, 64), s)
                mstore8(add(signature, 96), invalidV)
            }

            ActionData memory assetDataOut;
            ActionData memory transferFromOwner;
            ActionData memory assetDataIn;
            address[] memory to;
            bytes[] memory data;

            bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
            callData = abi.encode(assetDataOut, transferFromOwner, permit, signature, actionTargetData);
        }

        vm.prank(users.accountOwner);
        vm.expectRevert(SignatureVerification.InvalidSignature.selector);
        accountNotInitialised.flashAction(address(actionTarget), callData);
    }

    function testFuzz_Revert_flashAction_permit2_InvalidSigner(
        uint256 signerPrivateKey,
        uint256 token1Amount,
        uint256 stable1Amount,
        uint256 nonce
    ) public {
        // Private key must be less than the secp256k1 curve order and != 0
        signerPrivateKey = bound(
            signerPrivateKey,
            1,
            115_792_089_237_316_195_423_570_985_008_687_907_852_837_564_279_074_904_382_605_163_141_518_161_494_337 - 1
        );
        address signer = vm.addr(signerPrivateKey);

        // Initialize Account params
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setRegistry(address(registry));
        vm.prank(users.accountOwner);
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
        vm.startPrank(users.tokenCreator);
        mockERC20.token1.mint(users.accountOwner, token1Amount);
        mockERC20.stable1.mint(users.accountOwner, stable1Amount);
        vm.stopPrank();

        vm.startPrank(users.accountOwner);
        mockERC20.token1.approve(address(permit2), type(uint256).max);
        mockERC20.stable1.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        bytes memory callData;
        {
            // Generate struct PermitBatchTransferFrom
            IPermit2.PermitBatchTransferFrom memory permit =
                Utils.defaultERC20PermitMultiple(tokens, amounts, nonce, block.timestamp);

            // Get signature
            vm.prank(signer);
            bytes memory signature = Utils.getPermitBatchTransferSignature(
                permit, signerPrivateKey, permit2.DOMAIN_SEPARATOR(), address(accountNotInitialised)
            );

            ActionData memory assetDataOut;
            ActionData memory transferFromOwner;
            ActionData memory assetDataIn;
            address[] memory to;
            bytes[] memory data;

            bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
            callData = abi.encode(assetDataOut, transferFromOwner, permit, signature, actionTargetData);
        }

        vm.prank(users.accountOwner);
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        accountNotInitialised.flashAction(address(actionTarget), callData);
    }

    function testFuzz_Revert_flashAction_permit2_MaliciousSpender(
        uint256 ownerPrivateKey,
        uint256 token1Amount,
        uint256 stable1Amount,
        uint256 nonce,
        address maliciousActor
    ) public {
        // Given : Malicious actor is not the spender
        vm.assume(maliciousActor != address(accountNotInitialised));

        // Private key must be less than the secp256k1 curve order and != 0
        ownerPrivateKey = bound(
            ownerPrivateKey,
            1,
            115_792_089_237_316_195_423_570_985_008_687_907_852_837_564_279_074_904_382_605_163_141_518_161_494_337 - 1
        );
        address owner = vm.addr(ownerPrivateKey);

        // Initialize Account params
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(owner);
        accountNotInitialised.setRegistry(address(registry));
        vm.prank(owner);
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
        vm.startPrank(users.tokenCreator);
        mockERC20.token1.mint(owner, token1Amount);
        mockERC20.stable1.mint(owner, stable1Amount);
        vm.stopPrank();

        vm.startPrank(owner);
        mockERC20.token1.approve(address(permit2), type(uint256).max);
        mockERC20.stable1.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        // Generate struct PermitBatchTransferFrom
        IPermit2.PermitBatchTransferFrom memory permit =
            Utils.defaultERC20PermitMultiple(tokens, amounts, nonce, block.timestamp);

        // Get signature
        vm.prank(owner);
        bytes memory signature = Utils.getPermitBatchTransferSignature(
            permit, ownerPrivateKey, permit2.DOMAIN_SEPARATOR(), address(accountNotInitialised)
        );

        IPermit2.SignatureTransferDetails[] memory transferDetails = new IPermit2.SignatureTransferDetails[](2);
        transferDetails[0] =
            IPermit2.SignatureTransferDetails({ to: address(actionTarget), requestedAmount: token1Amount });
        transferDetails[1] =
            IPermit2.SignatureTransferDetails({ to: address(actionTarget), requestedAmount: stable1Amount });

        vm.prank(maliciousActor);
        // The following call should revert as the caller is not the spender.
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        permit2.permitTransferFrom(permit, transferDetails, owner, signature);
    }

    function testFuzz_Success_flashAction_Owner(
        uint32 time,
        uint32 minimumMargin,
        uint128 debtAmount,
        bytes calldata signature
    ) public {
        vm.assume(time > 2 days);
        vm.assume(time > 2 days);
        accountNotInitialised.setMinimumMargin(minimumMargin);
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setRegistry(address(registry));
        vm.prank(users.accountOwner);
        accountNotInitialised.setNumeraire(address(mockERC20.token1));
        accountNotInitialised.setCreditor(address(creditorStable1));

        creditorStable1.setOpenPosition(address(accountNotInitialised), debtAmount);

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);

        uint256 token1AmountForAction = 1000 * 10 ** Constants.TOKEN_DECIMALS;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.TOKEN_DECIMALS;
        uint256 stable1AmountForAction = 500 * 10 ** Constants.STABLE_DECIMALS;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        vm.assume(
            token1AmountForAction + ((uint256(debtAmount) + minimumMargin) * token1ToToken2Ratio) < type(uint256).max
        );

        // We increase the price of token 2 in order to avoid to end up with unhealthy state of account
        vm.startPrank(users.transmitter);
        mockOracles.token2ToUsd.transmit(int256(1000 * 10 ** Constants.TOKEN_ORACLE_DECIMALS));
        vm.stopPrank();

        ActionData[] memory actionDatas = new ActionData[](3);
        bytes memory callData;
        {
            bytes[] memory data = new bytes[](5);
            address[] memory to = new address[](5);

            data[0] = abi.encodeWithSignature(
                "approve(address,uint256)", address(routerMock), token1AmountForAction + uint256(debtAmount)
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
            vm.prank(users.tokenCreator);
            mockERC20.token2.mint(address(routerMock), token2AmountForAction + debtAmount * token1ToToken2Ratio);

            vm.prank(users.tokenCreator);
            mockERC20.token1.mint(address(actionTarget), debtAmount);

            to[0] = address(mockERC20.token1);
            to[1] = address(routerMock);
            to[2] = address(mockERC20.token2);
            to[3] = address(mockERC20.stable1);
            to[4] = address(mockERC721.nft1);

            actionDatas[0] = ActionData({
                assets: new address[](1),
                assetIds: new uint256[](1),
                assetAmounts: new uint256[](1),
                assetTypes: new uint256[](1)
            });

            actionDatas[0].assets[0] = address(mockERC20.token1);
            actionDatas[0].assetTypes[0] = 1;
            actionDatas[0].assetIds[0] = 0;
            actionDatas[0].assetAmounts[0] = token1AmountForAction;

            actionDatas[1] = ActionData({
                assets: new address[](3),
                assetIds: new uint256[](3),
                assetAmounts: new uint256[](3),
                assetTypes: new uint256[](3)
            });

            actionDatas[1].assets[0] = address(mockERC20.token2);
            // Add stable 1 that will be sent owner owner wallet to actionTarget contract
            actionDatas[1].assets[1] = address(mockERC20.stable1);
            // Add nft1 that will be sent owner owner wallet to actionTarget contract
            actionDatas[1].assets[2] = address(mockERC721.nft1);
            actionDatas[1].assetTypes[0] = 1;
            actionDatas[1].assetTypes[1] = 1;
            actionDatas[1].assetTypes[2] = 2;
            actionDatas[1].assetIds[0] = 0;
            actionDatas[1].assetIds[1] = 0;
            actionDatas[1].assetIds[2] = 1;
            actionDatas[1].assetAmounts[0] = token2AmountForAction + uint256(debtAmount) * token1ToToken2Ratio;
            actionDatas[1].assetAmounts[1] = stable1AmountForAction;
            actionDatas[1].assetAmounts[2] = 1;

            actionDatas[2] = ActionData({
                assets: new address[](2),
                assetIds: new uint256[](2),
                assetAmounts: new uint256[](2),
                assetTypes: new uint256[](2)
            });

            actionDatas[2].assets[0] = address(mockERC20.stable1);
            actionDatas[2].assets[1] = address(mockERC721.nft1);
            actionDatas[2].assetAmounts[0] = stable1AmountForAction;
            actionDatas[2].assetAmounts[1] = 1;
            actionDatas[2].assetTypes[0] = 1;
            actionDatas[2].assetTypes[1] = 2;
            actionDatas[2].assetIds[0] = 0;
            actionDatas[2].assetIds[1] = 1;

            IPermit2.TokenPermissions[] memory tokenPermissions;

            callData = abi.encode(
                actionDatas[0], actionDatas[2], tokenPermissions, signature, abi.encode(actionDatas[1], to, data)
            );
        }

        // Deposit token1 in account first
        depositErc20InAccount(
            mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountNotInitialised)
        );

        vm.startPrank(users.accountOwner);
        deal(address(mockERC20.stable1), users.accountOwner, stable1AmountForAction);
        mockERC721.nft1.mint(users.accountOwner, 1);
        // Approve the "stable1" and "nft1" tokens that will need to be transferred owner owner to actionTarget contract
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
        vm.startPrank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd));
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));
        mockOracles.nft1ToToken1.transmit(int256(rates.nft1ToToken1));
        // We increase the price of token 2 in order to avoid to end up with unhealthy state of account
        mockOracles.token2ToUsd.transmit(int256(1000 * 10 ** Constants.TOKEN_ORACLE_DECIMALS));
        vm.stopPrank();

        // Call flashAction() on Account
        vm.expectEmit(address(accountNotInitialised));
        emit AccountV3.Transfers(
            address(accountNotInitialised),
            address(actionTarget),
            actionDatas[0].assets,
            actionDatas[0].assetIds,
            actionDatas[0].assetAmounts,
            actionDatas[0].assetTypes
        );
        vm.expectEmit(address(accountNotInitialised));
        emit AccountV3.Transfers(
            users.accountOwner,
            address(actionTarget),
            actionDatas[2].assets,
            actionDatas[2].assetIds,
            actionDatas[2].assetAmounts,
            actionDatas[2].assetTypes
        );
        vm.expectEmit(address(accountNotInitialised));
        emit AccountV3.Transfers(
            address(actionTarget),
            address(accountNotInitialised),
            actionDatas[1].assets,
            actionDatas[1].assetIds,
            actionDatas[1].assetAmounts,
            actionDatas[1].assetTypes
        );
        vm.prank(users.accountOwner);
        accountNotInitialised.flashAction(address(actionTarget), callData);

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
        accountNotInitialised.setRegistry(address(registry));
        accountNotInitialised.setNumeraire(address(mockERC20.token1));
        accountNotInitialised.setCreditor(address(creditorStable1));
        vm.stopPrank();

        creditorStable1.setOpenPosition(address(accountNotInitialised), debtAmount);

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);

        uint256 token1AmountForAction = 1000 * 10 ** Constants.TOKEN_DECIMALS;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.TOKEN_DECIMALS;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        vm.assume(
            token1AmountForAction + ((uint256(debtAmount) + minimumMargin) * token1ToToken2Ratio) < type(uint256).max
        );

        bytes memory callData;
        {
            bytes[] memory data = new bytes[](3);
            address[] memory to = new address[](3);

            data[0] = abi.encodeWithSignature(
                "approve(address,uint256)", address(routerMock), token1AmountForAction + uint256(debtAmount)
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
            vm.prank(users.tokenCreator);
            mockERC20.token2.mint(address(routerMock), token2AmountForAction + debtAmount * token1ToToken2Ratio);

            vm.prank(users.tokenCreator);
            mockERC20.token1.mint(address(actionTarget), debtAmount);

            to[0] = address(mockERC20.token1);
            to[1] = address(routerMock);
            to[2] = address(mockERC20.token2);

            ActionData memory assetDataOut = ActionData({
                assets: new address[](1),
                assetIds: new uint256[](1),
                assetAmounts: new uint256[](1),
                assetTypes: new uint256[](1)
            });

            assetDataOut.assets[0] = address(mockERC20.token1);
            assetDataOut.assetTypes[0] = 1;
            assetDataOut.assetIds[0] = 0;
            assetDataOut.assetAmounts[0] = token1AmountForAction;

            ActionData memory assetDataIn = ActionData({
                assets: new address[](1),
                assetIds: new uint256[](1),
                assetAmounts: new uint256[](1),
                assetTypes: new uint256[](1)
            });

            assetDataIn.assets[0] = address(mockERC20.token2);
            assetDataIn.assetTypes[0] = 1;
            assetDataIn.assetIds[0] = 0;

            ActionData memory transferFromOwner;
            IPermit2.TokenPermissions[] memory tokenPermissions;

            callData = abi.encode(
                assetDataOut, transferFromOwner, tokenPermissions, signature, abi.encode(assetDataIn, to, data)
            );
        }

        vm.warp(time);

        // Deposit token1 in account first
        depositErc20InAccount(
            mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountNotInitialised)
        );

        vm.startPrank(users.transmitter);
        // We increase the price of token 2 in order to avoid to end up with unhealthy state of account
        mockOracles.token2ToUsd.transmit(int256(1000 * 10 ** Constants.TOKEN_ORACLE_DECIMALS));
        // We transmit price to token 1 oracle in order to have the oracle active
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd));
        vm.stopPrank();

        vm.startPrank(assetManager);

        // Assert the account has no TOKEN2 balance initially
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) == 0);

        // Call flashAction() on Account
        accountNotInitialised.flashAction(address(actionTarget), callData);

        // Assert that the Account now has a balance of TOKEN2
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) > 0);

        vm.stopPrank();

        // And: lastActionTimestamp is updated.
        assertEq(accountNotInitialised.lastActionTimestamp(), time);
    }

    function testFuzz_Success_flashAction_permit2(
        uint256 ownerPrivateKey,
        uint256 token1Amount,
        uint256 stable1Amount,
        uint256 nonce
    ) public {
        // Private key must be less than the secp256k1 curve order and != 0
        ownerPrivateKey = bound(
            ownerPrivateKey,
            1,
            115_792_089_237_316_195_423_570_985_008_687_907_852_837_564_279_074_904_382_605_163_141_518_161_494_337 - 1
        );
        address owner = vm.addr(ownerPrivateKey);

        // Initialize Account params
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(owner);
        accountNotInitialised.setRegistry(address(registry));
        vm.prank(owner);
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
        vm.startPrank(users.tokenCreator);
        mockERC20.token1.mint(owner, token1Amount);
        mockERC20.stable1.mint(owner, stable1Amount);
        vm.stopPrank();

        vm.startPrank(owner);
        mockERC20.token1.approve(address(permit2), type(uint256).max);
        mockERC20.stable1.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        bytes memory callData;
        {
            uint256 deadline = block.timestamp;

            // Generate struct PermitBatchTransferFrom
            IPermit2.PermitBatchTransferFrom memory permit =
                Utils.defaultERC20PermitMultiple(tokens, amounts, nonce, deadline);

            // Get signature
            vm.prank(owner);
            bytes memory signature = Utils.getPermitBatchTransferSignature(
                permit, ownerPrivateKey, permit2.DOMAIN_SEPARATOR(), address(accountNotInitialised)
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
        assertEq(mockERC20.token1.balanceOf(owner), token1Amount);
        assertEq(mockERC20.stable1.balanceOf(owner), stable1Amount);
        assertEq(mockERC20.token1.balanceOf(address(actionTarget)), 0);
        assertEq(mockERC20.stable1.balanceOf(address(actionTarget)), 0);

        // Call flashAction() on Account
        address[] memory assets = new address[](2);
        assets[0] = address(mockERC20.token1);
        assets[1] = address(mockERC20.stable1);
        uint256[] memory types = new uint256[](2);
        types[0] = 1;
        types[1] = 1;
        vm.expectEmit(address(accountNotInitialised));
        emit AccountV3.Transfers(address(owner), address(actionTarget), assets, new uint256[](2), amounts, types);
        vm.prank(owner);
        accountNotInitialised.flashAction(address(actionTarget), callData);

        // Check state after function call
        assertEq(mockERC20.token1.balanceOf(owner), 0);
        assertEq(mockERC20.stable1.balanceOf(owner), 0);
        assertEq(mockERC20.token1.balanceOf(address(actionTarget)), token1Amount);
        assertEq(mockERC20.stable1.balanceOf(address(actionTarget)), stable1Amount);
    }
}
