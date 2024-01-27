/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Constants, AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

import { ActionMultiCall } from "../../../../src/actions/MultiCall.sol";
import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { IActionBase, ActionData } from "../../../../src/interfaces/IActionBase.sol";
import { MultiActionMock } from "../../.././utils/mocks/actions/MultiActionMock.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { IPermit2 } from "../../../utils/Interfaces.sol";
import { Utils } from "../../../utils/Utils.sol";
import { Permit2Fixture } from "../../../utils/fixtures/permit2/Permit2Fixture.f.sol";

/**
 * @notice Fuzz tests for the function "flashActionByCreditor" of contract "AccountV1".
 */
contract FlashActionByCreditor_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test, Permit2Fixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    bytes internal emptyActionData;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountV1_Fuzz_Test, Permit2Fixture) {
        AccountV1_Fuzz_Test.setUp();
        Permit2Fixture.setUp();

        // Deploy multicall contract and actions
        action = new ActionMultiCall();
        multiActionMock = new MultiActionMock();

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
        address approvedCreditor
    ) public notTestContracts(sender) {
        vm.assume(sender != creditor);
        vm.assume(sender != approvedCreditor);

        vm.startPrank(users.accountOwner);
        accountExtension.setCreditor(creditor);
        accountExtension.setApprovedCreditor(approvedCreditor);
        vm.stopPrank();

        vm.prank(sender);
        vm.expectRevert(AccountErrors.OnlyCreditor.selector);
        accountExtension.flashActionByCreditor(address(action), new bytes(0));
    }

    function testFuzz_Revert_flashActionByCreditor_NonApprovedCreditorByOwner(
        address sender,
        address creditor,
        address approvedCreditor
    ) public {
        vm.assume(approvedCreditor != address(0));
        vm.assume(approvedCreditor != creditor);

        vm.prank(users.accountOwner);
        accountExtension.setCreditor(creditor);

        vm.prank(sender);
        accountExtension.setApprovedCreditor(approvedCreditor);

        vm.prank(approvedCreditor);
        vm.expectRevert(AccountErrors.OnlyCreditor.selector);
        accountExtension.flashActionByCreditor(address(action), new bytes(0));
    }

    function testFuzz_Revert_flashActionByCreditor_Reentered(address actionTarget, bytes calldata actionData) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.prank(address(creditorStable1));
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountExtension.flashActionByCreditor(actionTarget, actionData);
    }

    function testFuzz_Revert_flashActionByCreditor_InAuction(address actionTarget, bytes calldata actionData) public {
        // Will set "inAuction" to true.
        accountExtension.setInAuction();

        // Should revert if the Account is in an auction.
        vm.prank(address(creditorStable1));
        vm.expectRevert(AccountErrors.AccountInAuction.selector);
        accountExtension.flashActionByCreditor(actionTarget, actionData);
    }

    function testFuzz_Revert_flashActionByCreditor_NewCreditor_OverExposure(
        uint112 collateralAmount,
        uint112 maxExposure
    ) public {
        // Given: "exposure" is equal or bigger than "maxExposure".
        collateralAmount = uint112(bound(collateralAmount, 1, type(uint112).max - 1));
        maxExposure = uint112(bound(maxExposure, 0, collateralAmount));

        // And: MaxExposure for stable1 is set for both creditors.
        vm.startPrank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC20.stable1), 0, type(uint112).max, 0, 0
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC20.stable1), 0, maxExposure, 0, 0
        );
        vm.stopPrank();

        // And: The accountExtension has creditorStable1 set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // And: creditorToken1 is approved.
        vm.prank(users.accountOwner);
        accountExtension.setApprovedCreditor(address(creditorToken1));

        // And: The accountExtension has assets deposited.
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // When: The approved Creditor calls flashAction.
        // Then: Transaction should revert with ExposureNotInLimits.
        vm.prank(address(creditorToken1));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        accountExtension.flashActionByCreditor(address(action), emptyActionData);
    }

    function testFuzz_Revert_flashActionByCreditor_NewCreditor_InvalidAccountVersion(
        uint112 collateralAmount,
        uint112 maxExposure
    ) public {
        // Given: "collateralAmount" is smaller than "maxExposure".
        collateralAmount = uint112(bound(collateralAmount, 0, type(uint112).max - 1));
        maxExposure = uint112(bound(maxExposure, collateralAmount + 1, type(uint112).max));

        // And: MaxExposure for stable1 is set for both creditors.
        vm.startPrank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC20.stable1), 0, type(uint112).max, 0, 0
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC20.stable1), 0, maxExposure, 0, 0
        );
        vm.stopPrank();

        // And: The accountExtension has creditorStable1 set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // And: creditorToken1 is approved.
        vm.prank(users.accountOwner);
        accountExtension.setApprovedCreditor(address(creditorToken1));

        // And: The accountExtension has assets deposited.
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: The Account version will not be accepted by the Creditor.
        creditorToken1.setCallResult(false);

        // When: The approved Creditor calls flashAction.
        // Then: Transaction should revert with InvalidAccountVersion.
        vm.prank(address(creditorToken1));
        vm.expectRevert(AccountErrors.InvalidAccountVersion.selector);
        accountExtension.flashActionByCreditor(address(action), emptyActionData);
    }

    function testFuzz_Revert_flashActionByCreditor_NewCreditor_OpenPosition(
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
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: Both the old Creditor has an open position for the Account.
        oldCreditorDebtAmount = uint128(bound(oldCreditorDebtAmount, 1, type(uint128).max));
        creditorStable1.setOpenPosition(address(accountExtension), oldCreditorDebtAmount);

        // And: The new Creditor will have an open position after the flashaction.
        newCreditorDebtAmount = uint128(bound(newCreditorDebtAmount, 1, type(uint128).max));
        creditorToken1.setOpenPosition(address(accountExtension), newCreditorDebtAmount);

        // When: The approved Creditor calls flashAction.
        // Then: Transaction should revert with OpenPositionNonZero.
        vm.prank(address(creditorToken1));
        vm.expectRevert(OpenPositionNonZero.selector);
        accountExtension.flashActionByCreditor(address(action), emptyActionData);
    }

    function testFuzz_Revert_flashActionByCreditor_Creditor_Unhealthy(
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
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: The Creditor has an open position for the Account.
        accountExtension.setMinimumMargin(minimumMargin);
        creditorStable1.setOpenPosition(address(accountExtension), debtAmount);

        // When: The Creditor calls flashAction.
        // Then: Transaction should revert with AccountUnhealthy.
        vm.prank(address(creditorStable1));
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        accountExtension.flashActionByCreditor(address(action), emptyActionData);
    }

    function testFuzz_Revert_flashActionByCreditor_NewCreditor_Unhealthy(
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
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: The new Creditor will have an open position after the flashaction.
        creditorStable1.setMinimumMargin(minimumMargin);
        creditorStable1.setOpenPosition(address(accountExtension), debtAmount);

        // When: The Creditor calls flashAction.
        // Then: Transaction should revert with AccountUnhealthy.
        vm.prank(address(creditorStable1));
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        accountExtension.flashActionByCreditor(address(action), emptyActionData);
    }

    function testFuzz_Success_flashActionByCreditor_Creditor(
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
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: The Creditor has an open position for the Account.
        accountExtension.setMinimumMargin(minimumMargin);
        creditorStable1.setOpenPosition(address(accountExtension), debtAmount);

        // When: The Creditor calls flashAction.
        vm.prank(address(creditorStable1));
        uint256 accountVersion = accountExtension.flashActionByCreditor(address(action), emptyActionData);

        // Then: The Account version is returned.
        assertEq(accountVersion, 1);
    }

    function testFuzz_Success_flashActionByCreditor_NewCreditor_FromCreditor(
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
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: The new Creditor will have an open position after the flashaction.
        creditorStable1.setMinimumMargin(minimumMargin);
        creditorStable1.setOpenPosition(address(accountExtension), debtAmount);

        // When: The Creditor calls flashAction.
        vm.prank(address(creditorStable1));
        uint256 accountVersion = accountExtension.flashActionByCreditor(address(action), emptyActionData);

        // Then: The Account version is returned.
        assertEq(accountVersion, 1);

        // And: New Creditor is set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // And: Approved Creditor is reset.
        assertEq(accountExtension.approvedCreditor(users.accountOwner), address(0));

        // And: Exposure of old Creditor is removed.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1)));
        (uint128 actualExposure,,,) = erc20AssetModule.riskParams(address(creditorToken1), assetKey);
        assertEq(actualExposure, 0);

        // And: Exposure of new creditor is increased.
        (actualExposure,,,) = erc20AssetModule.riskParams(address(creditorStable1), assetKey);
        assertEq(actualExposure, collateralAmount);
    }

    function testFuzz_Success_flashActionByCreditor_NewCreditor_FromNoCreditor(
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
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralAmount);

        // And: The new Creditor will have an open position after the flashaction.
        creditorStable1.setMinimumMargin(minimumMargin);
        creditorStable1.setOpenPosition(address(accountExtension), debtAmount);

        // When: The Creditor calls flashAction.
        vm.prank(address(creditorStable1));
        uint256 accountVersion = accountExtension.flashActionByCreditor(address(action), emptyActionData);

        // Then: The Account version is returned.
        assertEq(accountVersion, 1);

        // And: New Creditor is set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // And: Approved Creditor is reset.
        assertEq(accountExtension.approvedCreditor(users.accountOwner), address(0));

        // And: Exposure of new creditor is increased.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1)));
        (uint256 actualExposure,,,) = erc20AssetModule.riskParams(address(creditorStable1), assetKey);
        assertEq(actualExposure, collateralAmount);
    }

    function testFuzz_Success_flashActionByCreditor_executeAction(
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

        uint256 token1AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token2AmountForAction = 1000 * 10 ** Constants.tokenDecimals;
        uint256 token1ToToken2Ratio = rates.token1ToUsd / rates.token2ToUsd;

        vm.assume(
            token1AmountForAction + ((uint256(debtAmount) + minimumMargin) * token1ToToken2Ratio) < type(uint256).max
        );

        // We increase the price of token 2 in order to avoid to end up with unhealthy state of accountExtension
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
            address(accountExtension),
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

        bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
        bytes memory callData =
            abi.encode(assetDataOut, transferFromOwner, tokenPermissions, signatureStack, actionTargetData);

        // Deposit token1 in accountExtension first
        depositERC20InAccount(mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountExtension));

        // Assert the accountExtension has no TOKEN2 balance initially
        assert(mockERC20.token2.balanceOf(address(accountExtension)) == 0);

        vm.warp(time);

        vm.startPrank(users.defaultTransmitter);
        // We increase the price of token 2 in order to avoid to end up with unhealthy state of account
        mockOracles.token2ToUsd.transmit(int256(1000 * 10 ** Constants.tokenOracleDecimals));
        // We transmit price to token 1 oracle in order to have the oracle active
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd));
        vm.stopPrank();

        // Call flashActionByCreditor() on Account
        vm.prank(address(creditorToken1));
        uint256 version = accountExtension.flashActionByCreditor(address(action), callData);

        // Assert that the Account now has a balance of TOKEN2
        assert(mockERC20.token2.balanceOf(address(accountExtension)) > 0);

        // Then: The action is successful
        assertEq(version, 1);

        // And: lastActionTimestamp is updated.
        assertEq(accountExtension.lastActionTimestamp(), time);
    }
}
