/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV3 } from "../../../../src/accounts/AccountV3.sol";
import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";
import { ActionData } from "../../../../src/interfaces/IActionBase.sol";
import { ActionTargetMock } from "../../../utils/mocks/action-targets/ActionTargetMock.sol";
import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { Constants } from "../../../utils/Constants.sol";
import { CreditorMock } from "../../../utils/mocks/creditors/CreditorMock.sol";
import { IPermit2 } from "../../../utils/interfaces/IPermit2.sol";
import { Permit2Fixture } from "../../../utils/fixtures/permit2/Permit2Fixture.f.sol";
import { RouterMock } from "../../.././utils/mocks/action-targets/RouterMock.sol";
import {
    SignatureVerification
} from "../../../../lib/v4-periphery/lib/permit2/src/libraries/SignatureVerification.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "flashActionByCreditor" of contract "AccountV3".
 */
contract FlashActionByCreditor_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test, Permit2Fixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    bytes internal emptyActionData;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountV3_Fuzz_Test, Permit2Fixture) {
        AccountV3_Fuzz_Test.setUp();
        Permit2Fixture.setUp();

        // Deploy multicall contract and actions
        actionTarget = new ActionTargetMock();
        routerMock = new RouterMock();

        ActionData memory actionData;
        address[] memory to;
        bytes[] memory data;
        bytes memory actionTargetData = abi.encode(actionData, to, data);
        IPermit2.PermitBatchTransferFrom memory permit;
        bytes memory signature;
        emptyActionData = abi.encode(actionData, actionData, permit, signature, actionTargetData);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_flashActionByCreditor_NonCreditor(
        address sender,
        address creditor,
        address approvedCreditor,
        bytes calldata callbackData
    ) public canReceiveERC721(sender) {
        vm.assume(sender != creditor);
        vm.assume(sender != approvedCreditor);

        vm.startPrank(users.accountOwner);
        accountExtension.setCreditor(creditor);
        accountExtension.setApprovedCreditor(approvedCreditor);
        vm.stopPrank();

        vm.prank(sender);
        vm.expectRevert(AccountErrors.OnlyCreditor.selector);
        accountExtension.flashActionByCreditor(callbackData, address(actionTarget), new bytes(0));
    }

    function testFuzz_Revert_flashActionByCreditor_NonApprovedCreditorByOwner(
        address sender,
        address creditor,
        address approvedCreditor,
        bytes calldata callbackData
    ) public {
        vm.assume(sender != users.accountOwner);
        vm.assume(approvedCreditor != address(0));
        vm.assume(approvedCreditor != creditor);

        vm.prank(users.accountOwner);
        accountExtension.setCreditor(creditor);

        vm.prank(sender);
        accountExtension.setApprovedCreditor(approvedCreditor);

        vm.prank(approvedCreditor);
        vm.expectRevert(AccountErrors.OnlyCreditor.selector);
        accountExtension.flashActionByCreditor(callbackData, address(actionTarget), new bytes(0));
    }

    function testFuzz_Revert_flashActionByCreditor_Reentered(
        bytes calldata callbackData,
        address actionTarget,
        bytes calldata actionData
    ) public {
        // Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        // Should revert if the reentrancy guard is locked.
        vm.prank(address(creditorStable1));
        vm.expectRevert(AccountsGuard.Reentered.selector);
        accountExtension.flashActionByCreditor(callbackData, actionTarget, actionData);
    }

    function testFuzz_Revert_flashActionByCreditor_InAuction(
        bytes calldata callbackData,
        address actionTarget,
        bytes calldata actionData
    ) public {
        // Will set "inAuction" to true.
        accountExtension.setInAuction();

        // Should revert if the Account is in an auction.
        vm.prank(address(creditorStable1));
        vm.expectRevert(AccountErrors.AccountInAuction.selector);
        accountExtension.flashActionByCreditor(callbackData, actionTarget, actionData);
    }

    function testFuzz_Revert_flashActionByCreditor_NewCreditor_OverExposure(
        bytes calldata callbackData,
        uint112 collateralAmount,
        uint112 maxExposure
    ) public {
        // Given: "exposure" is equal or bigger than "maxExposure".
        collateralAmount = uint112(bound(collateralAmount, 1, type(uint112).max - 1));
        maxExposure = uint112(bound(maxExposure, 0, collateralAmount));

        // And: MaxExposure for stable1 is set for both creditors.
        vm.startPrank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC20.stable1), 0, type(uint112).max, 0, 0
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC20.stable1), 0, maxExposure, 0, 0
        );
        vm.stopPrank();

        // And: The accountExtension has creditorStable1 set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // And: creditorToken1 is approved.
        vm.prank(users.accountOwner);
        accountExtension.setApprovedCreditor(address(creditorToken1));

        // And: The accountExtension has assets deposited.
        depositErc20InAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: the flashAction is initiated on the Creditor for the Account.
        creditorToken1.setCallbackAccount(address(accountExtension));

        // When: The approved Creditor calls flashAction.
        // Then: Transaction should revert with ExposureNotInLimits.
        vm.prank(address(creditorToken1));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        accountExtension.flashActionByCreditor(callbackData, address(actionTarget), emptyActionData);
    }

    function testFuzz_Revert_flashAction_permit2_InvalidSignatureLength(
        uint256 token1Amount,
        uint256 stable1Amount,
        uint256 nonce,
        bytes calldata invalidSignature
    ) public {
        vm.assume(invalidSignature.length != 65 && invalidSignature.length != 64);

        // Initialize Account params
        accountExtension.setLocked(1);
        accountExtension.setOwner(users.accountOwner);
        accountExtension.setRegistry(address(registry));
        vm.prank(users.accountOwner);
        accountExtension.setCreditor(address(creditorToken1));

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension))
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

        // And: the flashAction is initiated on the Creditor for the Account.
        creditorToken1.setCallbackAccount(address(accountExtension));

        // Call flashAction() on Account
        vm.prank(address(creditorToken1));
        vm.expectRevert(SignatureVerification.InvalidSignatureLength.selector);
        accountExtension.flashActionByCreditor("", address(actionTarget), callData);
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
        accountExtension.setLocked(1);
        accountExtension.setOwner(users.accountOwner);
        accountExtension.setRegistry(address(registry));
        vm.prank(users.accountOwner);
        accountExtension.setCreditor(address(creditorToken1));

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension))
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

        // And: the flashAction is initiated on the Creditor for the Account.
        creditorToken1.setCallbackAccount(address(accountExtension));

        // Call flashAction() on Account
        vm.prank(address(creditorToken1));
        vm.expectRevert(SignatureVerification.InvalidSignature.selector);
        accountExtension.flashActionByCreditor("", address(actionTarget), callData);
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
        accountExtension.setLocked(1);
        accountExtension.setOwner(users.accountOwner);
        accountExtension.setRegistry(address(registry));
        vm.prank(users.accountOwner);
        accountExtension.setCreditor(address(creditorToken1));

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension))
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
                permit, signerPrivateKey, permit2.DOMAIN_SEPARATOR(), address(accountExtension)
            );

            ActionData memory assetDataOut;
            ActionData memory transferFromOwner;
            ActionData memory assetDataIn;
            address[] memory to;
            bytes[] memory data;

            bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
            callData = abi.encode(assetDataOut, transferFromOwner, permit, signature, actionTargetData);
        }

        // And: the flashAction is initiated on the Creditor for the Account.
        creditorToken1.setCallbackAccount(address(accountExtension));

        // Call flashAction() on Account
        vm.prank(address(creditorToken1));
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        accountExtension.flashActionByCreditor("", address(actionTarget), callData);
    }

    function testFuzz_Revert_flashActionByCreditor_NewCreditor_InvalidAccountVersion(
        bytes calldata callbackData,
        uint112 collateralAmount,
        uint112 maxExposure
    ) public {
        // Given: "collateralAmount" is smaller than "maxExposure".
        collateralAmount = uint112(bound(collateralAmount, 0, type(uint112).max - 1));
        maxExposure = uint112(bound(maxExposure, collateralAmount + 1, type(uint112).max));

        // And: MaxExposure for stable1 is set for both creditors.
        vm.startPrank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC20.stable1), 0, type(uint112).max, 0, 0
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC20.stable1), 0, maxExposure, 0, 0
        );
        vm.stopPrank();

        // And: The accountExtension has creditorStable1 set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // And: creditorToken1 is approved.
        vm.prank(users.accountOwner);
        accountExtension.setApprovedCreditor(address(creditorToken1));

        // And: The accountExtension has assets deposited.
        depositErc20InAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: the flashAction is initiated on the Creditor for the Account.
        creditorToken1.setCallbackAccount(address(accountExtension));

        // And: The Account version will not be accepted by the Creditor.
        creditorToken1.setCallResult(false);

        // When: The approved Creditor calls flashAction.
        // Then: Transaction should revert with InvalidAccountVersion.
        vm.prank(address(creditorToken1));
        vm.expectRevert(AccountErrors.InvalidAccountVersion.selector);
        accountExtension.flashActionByCreditor(callbackData, address(actionTarget), emptyActionData);
    }

    function testFuzz_Revert_flashActionByCreditor_NewCreditor_OpenPosition(
        bytes calldata callbackData,
        uint128 oldCreditorDebtAmount,
        uint128 newCreditorDebtAmount,
        uint112 collateralAmount
    ) public {
        // Given: "exposure" is smaller than "maxExposure".
        collateralAmount = uint112(bound(collateralAmount, 0, type(uint112).max - 1));

        // And: The accountExtension has creditorStable1 set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // And: creditorToken1 is approved.
        vm.prank(users.accountOwner);
        accountExtension.setApprovedCreditor(address(creditorToken1));

        // And: The accountExtension has assets deposited.
        depositErc20InAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: Both the old Creditor has an open position for the Account.
        oldCreditorDebtAmount = uint128(bound(oldCreditorDebtAmount, 1, type(uint128).max));
        creditorStable1.setOpenPosition(address(accountExtension), oldCreditorDebtAmount);

        // And: The new Creditor will have an open position after the flashAction.
        newCreditorDebtAmount = uint128(bound(newCreditorDebtAmount, 1, type(uint128).max));
        creditorToken1.setOpenPosition(address(accountExtension), newCreditorDebtAmount);

        // And: the flashAction is initiated on the new Creditor for the Account.
        creditorToken1.setCallbackAccount(address(accountExtension));

        // When: The approved Creditor calls flashAction.
        // Then: Transaction should revert with OpenPositionNonZero.
        vm.prank(address(creditorToken1));
        vm.expectRevert(CreditorMock.OpenPositionNonZero.selector);
        accountExtension.flashActionByCreditor(callbackData, address(actionTarget), emptyActionData);
    }

    function testFuzz_Revert_flashActionByCreditor_Creditor_Unhealthy(
        bytes calldata callbackData,
        uint128 debtAmount,
        uint96 minimumMargin,
        uint112 collateralAmount
    ) public {
        // Given: "exposure" is smaller than "maxExposure".
        collateralAmount = uint112(bound(collateralAmount, 0, type(uint112).max - 1));

        // And: Account is unhealthy after flash-action.
        debtAmount = uint128(bound(debtAmount, 1, type(uint128).max));
        collateralAmount = uint112(bound(collateralAmount, 0, uint256(debtAmount) + minimumMargin - 1));

        // And: The accountExtension has creditorStable1 set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // And: The accountExtension has assets deposited.
        depositErc20InAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: The Creditor has an open position for the Account.
        accountExtension.setMinimumMargin(minimumMargin);
        creditorStable1.setOpenPosition(address(accountExtension), debtAmount);

        // And: the flashAction is initiated on the Creditor for the Account.
        creditorStable1.setCallbackAccount(address(accountExtension));

        // When: The Creditor calls flashAction.
        // Then: Transaction should revert with AccountUnhealthy.
        vm.prank(address(creditorStable1));
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        accountExtension.flashActionByCreditor(callbackData, address(actionTarget), emptyActionData);
    }

    function testFuzz_Revert_flashActionByCreditor_NewCreditor_Unhealthy(
        bytes calldata callbackData,
        uint128 debtAmount,
        uint96 minimumMargin,
        uint112 collateralAmount
    ) public {
        // Given: "exposure" is smaller than "maxExposure".
        collateralAmount = uint112(bound(collateralAmount, 0, type(uint112).max - 1));

        // And: Account is unhealthy after flash-action.
        debtAmount = uint128(bound(debtAmount, 1, type(uint128).max));
        collateralAmount = uint112(bound(collateralAmount, 0, uint256(debtAmount) + minimumMargin - 1));

        // And: The accountExtension has creditorToken1 set.
        vm.prank(users.accountOwner);
        accountExtension.openMarginAccount(address(creditorToken1));

        // And: creditorStable1 is approved.
        vm.prank(users.accountOwner);
        accountExtension.setApprovedCreditor(address(creditorStable1));

        // And: The accountExtension has assets deposited.
        depositErc20InAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: The new Creditor will have an open position after the flashAction.
        creditorStable1.setMinimumMargin(minimumMargin);
        creditorStable1.setOpenPosition(address(accountExtension), debtAmount);

        // And: the flashAction is initiated on the new Creditor for the Account.
        creditorStable1.setCallbackAccount(address(accountExtension));

        // When: The Creditor calls flashAction.
        // Then: Transaction should revert with AccountUnhealthy.
        vm.prank(address(creditorStable1));
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        accountExtension.flashActionByCreditor(callbackData, address(actionTarget), emptyActionData);
    }

    function testFuzz_Success_flashActionByCreditor_Creditor(
        bytes calldata callbackData,
        uint128 debtAmount,
        uint96 minimumMargin,
        uint112 collateralAmount
    ) public {
        // Given: "exposure" is smaller than "maxExposure".
        collateralAmount = uint112(bound(collateralAmount, 0, type(uint112).max - 1));

        // And: Account is healthy after flash-action.
        debtAmount = uint128(bound(debtAmount, 0, collateralAmount));
        minimumMargin = uint96(bound(minimumMargin, 0, collateralAmount - debtAmount));

        // And: The accountExtension has creditorStable1 set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // And: The accountExtension has assets deposited.
        depositErc20InAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: The Creditor has an open position for the Account.
        accountExtension.setMinimumMargin(minimumMargin);
        creditorStable1.setOpenPosition(address(accountExtension), debtAmount);

        // And: the flashAction is initiated on the Creditor for the Account.
        creditorStable1.setCallbackAccount(address(accountExtension));

        // When: The Creditor calls flashAction.
        vm.prank(address(creditorStable1));
        uint256 accountVersion =
            accountExtension.flashActionByCreditor(callbackData, address(actionTarget), emptyActionData);

        // Then: The Account version is returned.
        assertEq(accountVersion, 3);
    }

    function testFuzz_Success_flashActionByCreditor_NewCreditor_FromCreditor(
        bytes calldata callbackData,
        uint128 debtAmount,
        uint96 minimumMargin,
        uint112 collateralAmount
    ) public {
        // Given: "exposure" is smaller than "maxExposure".
        collateralAmount = uint112(bound(collateralAmount, 0, type(uint112).max - 1));

        // And: Account is healthy after flash-action.
        debtAmount = uint128(bound(debtAmount, 0, collateralAmount));
        minimumMargin = uint96(bound(minimumMargin, 0, collateralAmount - debtAmount));

        // And: The accountExtension has creditorToken1 set.
        vm.prank(users.accountOwner);
        accountExtension.openMarginAccount(address(creditorToken1));

        // And: creditorStable1 is approved.
        vm.prank(users.accountOwner);
        accountExtension.setApprovedCreditor(address(creditorStable1));

        // And: The accountExtension has assets deposited.
        depositErc20InAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: The new Creditor will have an open position after the flashAction.
        creditorStable1.setMinimumMargin(minimumMargin);
        creditorStable1.setOpenPosition(address(accountExtension), debtAmount);

        // And: the flashAction is initiated on the Creditor for the Account.
        creditorStable1.setCallbackAccount(address(accountExtension));

        // When: The Creditor calls flashAction.
        vm.prank(address(creditorStable1));
        uint256 accountVersion =
            accountExtension.flashActionByCreditor(callbackData, address(actionTarget), emptyActionData);

        // Then: The Account version is returned.
        assertEq(accountVersion, 3);

        // And: New Creditor is set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // And: Approved Creditor is reset.
        assertEq(accountExtension.approvedCreditor(users.accountOwner), address(0));

        // And: Exposure of old Creditor is removed.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1)));
        (uint128 actualExposure,,,) = erc20AM.riskParams(address(creditorToken1), assetKey);
        assertEq(actualExposure, 0);

        // And: Exposure of new creditor is increased.
        (actualExposure,,,) = erc20AM.riskParams(address(creditorStable1), assetKey);
        assertEq(actualExposure, collateralAmount);
    }

    function testFuzz_Success_flashActionByCreditor_NewCreditor_FromNoCreditor(
        bytes calldata callbackData,
        uint128 debtAmount,
        uint96 minimumMargin,
        uint112 collateralAmount
    ) public {
        // Given: "exposure" is smaller than "maxExposure".
        collateralAmount = uint112(bound(collateralAmount, 0, type(uint112).max - 1));

        // And: Account is healthy after flash-action.
        debtAmount = uint128(bound(debtAmount, 0, collateralAmount));
        minimumMargin = uint96(bound(minimumMargin, 0, collateralAmount - debtAmount));

        // And: No Creditor is set.
        vm.prank(users.accountOwner);
        accountExtension.closeMarginAccount();

        // And: creditorStable1 is approved.
        vm.prank(users.accountOwner);
        accountExtension.setApprovedCreditor(address(creditorStable1));

        // And: The accountExtension has assets deposited.
        depositErc20InAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: The new Creditor will have an open position after the flashAction.
        creditorStable1.setMinimumMargin(minimumMargin);
        creditorStable1.setOpenPosition(address(accountExtension), debtAmount);

        // And: the flashAction is initiated on the Creditor for the Account.
        creditorStable1.setCallbackAccount(address(accountExtension));

        // When: The Creditor calls flashAction.
        vm.prank(address(creditorStable1));
        uint256 accountVersion =
            accountExtension.flashActionByCreditor(callbackData, address(actionTarget), emptyActionData);

        // Then: The Account version is returned.
        assertEq(accountVersion, 3);

        // And: New Creditor is set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // And: Approved Creditor is reset.
        assertEq(accountExtension.approvedCreditor(users.accountOwner), address(0));

        // And: Exposure of new creditor is increased.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1)));
        (uint256 actualExposure,,,) = erc20AM.riskParams(address(creditorStable1), assetKey);
        assertEq(actualExposure, collateralAmount);
    }

    function testFuzz_Success_flashActionByCreditor_executeAction(
        bytes calldata callbackData,
        uint128 debtAmount,
        uint32 minimumMargin,
        bytes calldata signature,
        uint32 time
    ) public {
        vm.assume(time > 2 days);
        vm.prank(users.accountOwner);
        accountExtension.openMarginAccount(address(creditorToken1));

        accountExtension.setMinimumMargin(minimumMargin);
        creditorToken1.setOpenPosition(address(accountExtension), debtAmount);

        ActionData[] memory actionDatas = new ActionData[](3);
        bytes memory callData;
        {
            uint256 token1AmountForAction = 1000 * 10 ** Constants.TOKEN_DECIMALS;
            uint256 token2AmountForAction = 1000 * 10 ** Constants.TOKEN_DECIMALS;
            uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

            vm.assume(
                token1AmountForAction + ((uint256(debtAmount) + minimumMargin) * token1ToToken2Ratio)
                    < type(uint256).max
            );

            // We increase the price of token 2 in order to avoid to end up with unhealthy state of accountExtension
            vm.startPrank(users.transmitter);
            mockOracles.token2ToUsd.transmit(int256(1000 * 10 ** Constants.TOKEN_ORACLE_DECIMALS));
            vm.stopPrank();

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
                address(accountExtension),
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
                assets: new address[](1),
                assetIds: new uint256[](1),
                assetAmounts: new uint256[](1),
                assetTypes: new uint256[](1)
            });

            actionDatas[1].assets[0] = address(mockERC20.token2);
            actionDatas[1].assetTypes[0] = 1;
            actionDatas[1].assetIds[0] = 0;
            actionDatas[1].assetAmounts[0] = token1AmountForAction + uint256(debtAmount) * token1ToToken2Ratio;

            ActionData memory transferFromOwner;
            IPermit2.TokenPermissions[] memory tokenPermissions;

            // Avoid stack too deep
            bytes memory signatureStack = signature;

            bytes memory actionTargetData = abi.encode(actionDatas[1], to, data);
            callData = abi.encode(actionDatas[0], transferFromOwner, tokenPermissions, signatureStack, actionTargetData);

            // Deposit token1 in accountExtension first
            depositErc20InAccount(
                mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountExtension)
            );
        }

        // Assert the accountExtension has no TOKEN2 balance initially
        assert(mockERC20.token2.balanceOf(address(accountExtension)) == 0);

        vm.warp(time);

        vm.startPrank(users.transmitter);
        // We increase the price of token 2 in order to avoid to end up with unhealthy state of account
        mockOracles.token2ToUsd.transmit(int256(1000 * 10 ** Constants.TOKEN_ORACLE_DECIMALS));
        // We transmit price to token 1 oracle in order to have the oracle active
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd));
        vm.stopPrank();

        // And: the flashAction is initiated on the Creditor for the Account.
        creditorToken1.setCallbackAccount(address(accountExtension));

        // Call flashActionByCreditor() on Account
        vm.expectEmit(address(accountExtension));
        emit AccountV3.Transfers(
            address(accountExtension),
            address(actionTarget),
            actionDatas[0].assets,
            actionDatas[0].assetIds,
            actionDatas[0].assetAmounts,
            actionDatas[0].assetTypes
        );
        vm.expectEmit(address(accountExtension));
        emit AccountV3.Transfers(
            address(actionTarget),
            address(accountExtension),
            actionDatas[1].assets,
            actionDatas[1].assetIds,
            actionDatas[1].assetAmounts,
            actionDatas[1].assetTypes
        );
        vm.prank(address(creditorToken1));
        uint256 version = accountExtension.flashActionByCreditor(callbackData, address(actionTarget), callData);

        // Assert that the Account now has a balance of TOKEN2
        assert(mockERC20.token2.balanceOf(address(accountExtension)) > 0);

        // Then: The actionTarget is successful
        assertEq(version, 3);

        // And: lastActionTimestamp is updated.
        assertEq(accountExtension.lastActionTimestamp(), time);
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
        accountExtension.setLocked(1);
        accountExtension.setOwner(owner);
        accountExtension.setRegistry(address(registry));
        vm.prank(owner);
        accountExtension.setCreditor(address(creditorToken1));

        // Set the account as initialised in the factory
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension))
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
                permit, ownerPrivateKey, permit2.DOMAIN_SEPARATOR(), address(accountExtension)
            );

            ActionData memory assetDataOut;
            ActionData memory transferFromOwner;
            ActionData memory assetDataIn;
            address[] memory to;
            bytes[] memory data;

            bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
            callData = abi.encode(assetDataOut, transferFromOwner, permit, signature, actionTargetData);
        }

        // And: the flashAction is initiated on the Creditor for the Account.
        creditorToken1.setCallbackAccount(address(accountExtension));

        // Check state pre function call
        assertEq(mockERC20.token1.balanceOf(owner), token1Amount);
        assertEq(mockERC20.stable1.balanceOf(owner), stable1Amount);
        assertEq(mockERC20.token1.balanceOf(address(actionTarget)), 0);
        assertEq(mockERC20.stable1.balanceOf(address(actionTarget)), 0);

        // Call flashActionByCreditor() on Account
        address[] memory assets = new address[](2);
        assets[0] = address(mockERC20.token1);
        assets[1] = address(mockERC20.stable1);
        uint256[] memory types = new uint256[](2);
        types[0] = 1;
        types[1] = 1;
        vm.expectEmit(address(accountExtension));
        emit AccountV3.Transfers(address(owner), address(actionTarget), assets, new uint256[](2), amounts, types);
        vm.prank(address(creditorToken1));
        accountExtension.flashActionByCreditor("", address(actionTarget), callData);

        // Check state after function call
        assertEq(mockERC20.token1.balanceOf(owner), 0);
        assertEq(mockERC20.stable1.balanceOf(owner), 0);
        assertEq(mockERC20.token1.balanceOf(address(actionTarget)), token1Amount);
        assertEq(mockERC20.stable1.balanceOf(address(actionTarget)), stable1Amount);
    }
}
