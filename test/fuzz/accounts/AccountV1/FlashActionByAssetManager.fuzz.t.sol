/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Constants, AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

import { AccountExtension, AccountV1 } from "../../../utils/Extensions.sol";
import { IActionBase, ActionData } from "../../../../src/interfaces/IActionBase.sol";
import { ActionMultiCall } from "../../../../src/actions/MultiCall.sol";
import { MultiActionMock } from "../../.././utils/mocks/MultiActionMock.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { IPermit2 } from "../../../utils/Interfaces.sol";
import { Utils } from "../../../utils/Utils.sol";
import { Permit2Fixture } from "../../../utils/fixtures/permit2/Permit2Fixture.f.sol";

/**
 * @notice Fuzz tests for the function "flashActionByAssetManager" of contract "AccountV1".
 */
contract FlashActionByAssetManager_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test, Permit2Fixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountExtension internal accountNotInitialised;
    ActionMultiCall internal action;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountV1_Fuzz_Test, Permit2Fixture) {
        AccountV1_Fuzz_Test.setUp();
        Permit2Fixture.setUp();

        // Deploy multicall contract and actions
        action = new ActionMultiCall();
        multiActionMock = new MultiActionMock();

        accountNotInitialised = new AccountExtension();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_flashActionByAssetManager_NonAssetManager(address sender, address assetManager)
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
        accountExtension.flashActionByAssetManager(address(action), new bytes(0));
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_OwnerChanged(address assetManager) public {
        vm.assume(assetManager != address(0));
        address newOwner = address(60); //Annoying to fuzz since it often fuzzes to existing contracts without an onERC721Received
        vm.assume(assetManager != newOwner);

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
        proxy.flashActionByAssetManager(address(action), new bytes(0));
        vm.stopPrank();
    }

    function testFuzz_Success_flashActionByAssetManager_Owner(
        uint128 debtAmount,
        uint32 fixedLiquidationCost,
        bytes calldata signature
    ) public {
        accountNotInitialised.setFixedLiquidationCost(fixedLiquidationCost);
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

        // Bring signature back to stack to avoid stack too deep below
        bytes calldata signatureStack = signature;

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

        bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
        bytes memory callData =
            abi.encode(assetDataOut, transferFromOwner, tokenPermissions, signatureStack, actionTargetData);

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

        // Call flashActionByAssetManager() on Account
        accountNotInitialised.flashActionByAssetManager(address(action), callData);

        // Assert that the Account now has a balance of TOKEN2 and STABLE1
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) > 0);
        assert(mockERC20.stable1.balanceOf(address(accountNotInitialised)) == stable1AmountForAction);
        // Assert that token id 1 of mockERC721.nft1 contract was transferred to the Account
        assert(mockERC721.nft1.ownerOf(1) == address(accountNotInitialised));

        vm.stopPrank();
    }

    function testFuzz_Success_flashActionByAssetManager_AssetManager(
        uint128 debtAmount,
        uint32 fixedLiquidationCost,
        address assetManager,
        bytes calldata signature
    ) public {
        vm.assume(users.accountOwner != assetManager);
        vm.startPrank(users.accountOwner);
        accountNotInitialised.setFixedLiquidationCost(fixedLiquidationCost);
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

        // Avoid stack too deep
        bytes memory signatureStack = signature;
        address assetManagerStack = assetManager;

        bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
        bytes memory callData =
            abi.encode(assetDataOut, transferFromOwner, tokenPermissions, signatureStack, actionTargetData);

        // Deposit token1 in account first
        depositERC20InAccount(
            mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountNotInitialised)
        );

        vm.startPrank(assetManagerStack);

        // Assert the account has no TOKEN2 balance initially
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) == 0);

        // Call flashActionByAssetManager() on Account
        accountNotInitialised.flashActionByAssetManager(address(action), callData);

        // Assert that the Account now has a balance of TOKEN2
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) > 0);

        vm.stopPrank();
    }
}
