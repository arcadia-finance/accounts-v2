/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV4 } from "../../../../src/accounts/AccountV4.sol";
import { AccountV4_Fuzz_Test } from "./_AccountV4.fuzz.t.sol";
import { AccountV4Extension } from "../../../utils/extensions/AccountV4Extension.sol";
import { ActionData } from "../../../../src/interfaces/IActionBase.sol";
import { ActionMultiCall } from "../../../../src/actions/MultiCall.sol";
import { Constants } from "../../../utils/Constants.sol";
import { IPermit2 } from "../../../utils/Interfaces.sol";
import { MultiActionMock } from "../../.././utils/mocks/actions/MultiActionMock.sol";
import { Permit2Fixture } from "../../../utils/fixtures/permit2/Permit2Fixture.f.sol";
import { SignatureVerification } from "../../../../lib/v4-periphery/lib/permit2/src/libraries/SignatureVerification.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "flashAction" of contract "AccountV4".
 */
contract FlashAction_AccountV4_Fuzz_Test is AccountV4_Fuzz_Test, Permit2Fixture {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountV4_Fuzz_Test, Permit2Fixture) {
        AccountV4_Fuzz_Test.setUp();
        Permit2Fixture.setUp();

        // Deploy multicall contract and actions
        action = new ActionMultiCall();
        multiActionMock = new MultiActionMock();
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
        accountSpot.setAssetManager(assetManager, true);

        vm.startPrank(sender);
        vm.expectRevert("A: Only Asset Manager");
        accountSpot.flashAction(address(action), new bytes(0));
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
        address payable proxyAddr = payable(factory.createAccount(12_345_678, 0, address(0)));
        AccountV4Extension proxy = AccountV4Extension(proxyAddr);
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
        accountsGuard.setAccount(address(1));

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountsGuard.Reentered.selector);
        accountSpot.flashAction(actionTarget, actionData);
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_permit2_InvalidSignatureLength(
        uint256 token1Amount,
        uint256 stable1Amount,
        uint256 nonce,
        bytes calldata invalidSignature
    ) public {
        vm.assume(invalidSignature.length != 65 && invalidSignature.length != 64);

        // Set owner for Account
        accountSpot.setOwner(users.accountOwner);

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
        accountSpot.flashAction(address(action), callData);
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

        // Set owner for Account
        accountSpot.setOwner(users.accountOwner);

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
        accountSpot.flashAction(address(action), callData);
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

        // Set owner for Account
        accountSpot.setOwner(users.accountOwner);

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
                permit, signerPrivateKey, permit2.DOMAIN_SEPARATOR(), address(accountSpot)
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
        accountSpot.flashAction(address(action), callData);
    }

    function testFuzz_Revert_flashAction_permit2_maliciousSpender(
        uint256 ownerPrivateKey,
        uint256 token1Amount,
        uint256 stable1Amount,
        uint256 nonce,
        address maliciousActor
    ) public {
        // Given : Malicious actor is not the spender
        vm.assume(maliciousActor != address(accountSpot));

        // Private key must be less than the secp256k1 curve order and != 0
        ownerPrivateKey = bound(
            ownerPrivateKey,
            1,
            115_792_089_237_316_195_423_570_985_008_687_907_852_837_564_279_074_904_382_605_163_141_518_161_494_337 - 1
        );
        address owner = vm.addr(ownerPrivateKey);

        // Set owner for Account
        accountSpot.setOwner(owner);

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
        IPermit2.PermitBatchTransferFrom memory permit;
        {
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = token1Amount;
            amounts[1] = stable1Amount;

            address[] memory tokens = new address[](2);
            tokens[0] = address(mockERC20.token1);
            tokens[1] = address(mockERC20.stable1);

            permit = Utils.defaultERC20PermitMultiple(tokens, amounts, nonce, block.timestamp);
        }

        // Get signature
        vm.prank(owner);
        bytes memory signature = Utils.getPermitBatchTransferSignature(
            permit, ownerPrivateKey, permit2.DOMAIN_SEPARATOR(), address(accountSpot)
        );

        IPermit2.SignatureTransferDetails[] memory transferDetails = new IPermit2.SignatureTransferDetails[](2);
        transferDetails[0] = IPermit2.SignatureTransferDetails({ to: address(action), requestedAmount: token1Amount });
        transferDetails[1] = IPermit2.SignatureTransferDetails({ to: address(action), requestedAmount: stable1Amount });

        vm.prank(maliciousActor);
        // The following call should revert as the caller is not the spender.
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        permit2.permitTransferFrom(permit, transferDetails, owner, signature);
    }

    function testFuzz_Success_flashAction_Owner(uint32 time, bytes calldata signature) public {
        vm.assume(time > 2 days);
        vm.assume(time > 2 days);

        uint256 token1AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 stable1AmountForAction = 500 * 10 ** Constants.stableDecimals;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        ActionData[] memory actionDatas = new ActionData[](3);
        bytes memory callData;
        {
            bytes[] memory data = new bytes[](5);
            address[] memory to = new address[](5);

            data[0] =
                abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), token1AmountForAction);
            data[1] = abi.encodeWithSignature(
                "swapAssets(address,address,uint256,uint256)",
                address(mockERC20.token1),
                address(mockERC20.token2),
                token1AmountForAction,
                token2AmountForAction * token1ToToken2Ratio
            );
            data[2] = abi.encodeWithSignature(
                "approve(address,uint256)", address(accountSpot), token2AmountForAction * token1ToToken2Ratio
            );
            data[3] = abi.encodeWithSignature("approve(address,uint256)", address(accountSpot), stable1AmountForAction);
            data[4] = abi.encodeWithSignature("approve(address,uint256)", address(accountSpot), 1);

            vm.prank(users.tokenCreator);
            mockERC20.token2.mint(address(multiActionMock), token2AmountForAction * token1ToToken2Ratio);

            to[0] = address(mockERC20.token1);
            to[1] = address(multiActionMock);
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
            // Add stable 1 that will be sent owner owner wallet to action contract
            actionDatas[1].assets[1] = address(mockERC20.stable1);
            // Add nft1 that will be sent owner owner wallet to action contract
            actionDatas[1].assets[2] = address(mockERC721.nft1);
            actionDatas[1].assetTypes[0] = 1;
            actionDatas[1].assetTypes[1] = 1;
            actionDatas[1].assetTypes[2] = 2;
            actionDatas[1].assetIds[0] = 0;
            actionDatas[1].assetIds[1] = 0;
            actionDatas[1].assetIds[2] = 1;
            actionDatas[1].assetAmounts[0] = token2AmountForAction * token1ToToken2Ratio;
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
        mockERC20.token1.mint(address(accountSpot), token1AmountForAction);

        vm.startPrank(users.accountOwner);
        deal(address(mockERC20.stable1), users.accountOwner, stable1AmountForAction);
        mockERC721.nft1.mint(users.accountOwner, 1);
        // Approve the "stable1" and "nft1" tokens that will need to be transferred owner owner to action contract
        mockERC20.stable1.approve(address(accountSpot), stable1AmountForAction);
        mockERC721.nft1.approve(address(accountSpot), 1);
        vm.stopPrank();

        // Assert the Account has no TOKEN2 and STABLE1 balance initially
        assertEq(mockERC20.token2.balanceOf(address(accountSpot)), 0);
        assertEq(mockERC20.stable1.balanceOf(address(accountSpot)), 0);
        // Assert the owner of token id 1 of mockERC721.nft1 contract is accountOwner
        assertEq(mockERC721.nft1.ownerOf(1), users.accountOwner);

        vm.warp(time);

        // Call flashAction() on Account
        vm.prank(users.accountOwner);
        vm.expectEmit(address(accountSpot));
        emit AccountV4.Transfers(
            address(accountSpot),
            address(action),
            actionDatas[0].assets,
            actionDatas[0].assetIds,
            actionDatas[0].assetAmounts,
            actionDatas[0].assetTypes
        );
        vm.expectEmit(address(accountSpot));
        emit AccountV4.Transfers(
            users.accountOwner,
            address(action),
            actionDatas[2].assets,
            actionDatas[2].assetIds,
            actionDatas[2].assetAmounts,
            actionDatas[2].assetTypes
        );
        vm.expectEmit(address(accountSpot));
        emit AccountV4.Transfers(
            address(action),
            address(accountSpot),
            actionDatas[1].assets,
            actionDatas[1].assetIds,
            actionDatas[1].assetAmounts,
            actionDatas[1].assetTypes
        );
        accountSpot.flashAction(address(action), callData);

        // Assert that the Account now has a balance of TOKEN2 and STABLE1
        assertGt(mockERC20.token2.balanceOf(address(accountSpot)), 0);
        assertEq(mockERC20.stable1.balanceOf(address(accountSpot)), stable1AmountForAction);
        // Assert that token id 1 of mockERC721.nft1 contract was transferred to the Account
        assertEq(mockERC721.nft1.ownerOf(1), address(accountSpot));

        // And: lastActionTimestamp is updated.
        assertEq(accountSpot.lastActionTimestamp(), time);
    }

    function testFuzz_Success_flashActionByAssetManager_AssetManager(
        address assetManager,
        uint32 time,
        bytes calldata signature
    ) public {
        vm.assume(time > 2 days);
        vm.assume(users.accountOwner != assetManager);
        vm.startPrank(users.accountOwner);
        accountSpot.setAssetManager(assetManager, true);
        vm.stopPrank();

        uint256 token1AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        bytes memory callData;
        {
            bytes[] memory data = new bytes[](3);
            address[] memory to = new address[](3);

            data[0] =
                abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), token1AmountForAction);
            data[1] = abi.encodeWithSignature(
                "swapAssets(address,address,uint256,uint256)",
                address(mockERC20.token1),
                address(mockERC20.token2),
                token1AmountForAction,
                token2AmountForAction * token1ToToken2Ratio
            );
            data[2] = abi.encodeWithSignature(
                "approve(address,uint256)", address(accountSpot), token2AmountForAction * token1ToToken2Ratio
            );

            mockERC20.token2.mint(address(multiActionMock), token2AmountForAction * token1ToToken2Ratio);

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
        mockERC20.token1.mint(address(accountSpot), token1AmountForAction);

        vm.startPrank(assetManager);

        // Assert the account has no TOKEN2 balance initially
        assertEq(mockERC20.token2.balanceOf(address(accountSpot)), 0);

        // Call flashAction() on Account
        accountSpot.flashAction(address(action), callData);

        // Assert that the Account now has a balance of TOKEN2
        assertGt(mockERC20.token2.balanceOf(address(accountSpot)), 0);

        vm.stopPrank();

        // And: lastActionTimestamp is updated.
        assertEq(accountSpot.lastActionTimestamp(), time);
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
        accountSpot.setOwner(owner);

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

            bytes32 DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

            // Get signature
            vm.prank(owner);
            bytes memory signature =
                Utils.getPermitBatchTransferSignature(permit, ownerPrivateKey, DOMAIN_SEPARATOR, address(accountSpot));

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
        assertEq(mockERC20.token1.balanceOf(address(action)), 0);
        assertEq(mockERC20.stable1.balanceOf(address(action)), 0);

        // Call flashAction() on Account
        address[] memory assets = new address[](2);
        assets[0] = address(mockERC20.token1);
        assets[1] = address(mockERC20.stable1);
        uint256[] memory types = new uint256[](2);
        types[0] = 1;
        types[1] = 1;
        vm.expectEmit(address(accountSpot));
        emit AccountV4.Transfers(address(owner), address(action), assets, new uint256[](2), amounts, types);
        vm.prank(owner);
        accountSpot.flashAction(address(action), callData);

        // Check state after function call
        assertEq(mockERC20.token1.balanceOf(owner), 0);
        assertEq(mockERC20.stable1.balanceOf(owner), 0);
        assertEq(mockERC20.token1.balanceOf(address(action)), token1Amount);
        assertEq(mockERC20.stable1.balanceOf(address(action)), stable1Amount);
    }

    function testFuzz_Success_flashAction_NativeEth(uint112 amount) public {
        // Given: Owner has enough balance.
        vm.deal(users.accountOwner, amount);

        bytes memory callData;
        {
            bytes[] memory data = new bytes[](0);
            address[] memory to = new address[](0);

            ActionData memory actionData;
            IPermit2.TokenPermissions[] memory tokenPermissions;
            bytes memory signature;

            callData = abi.encode(actionData, actionData, tokenPermissions, signature, abi.encode(actionData, to, data));
        }

        // When: Native ETH is deposited into spot Account.
        vm.prank(users.accountOwner);
        accountSpot.flashAction{ value: amount }(address(action), callData);

        // Then : It should return the correct balance.
        assertEq(address(accountSpot).balance, amount);
    }
}
