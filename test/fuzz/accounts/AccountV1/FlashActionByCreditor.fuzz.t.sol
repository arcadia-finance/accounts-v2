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
 * @notice Fuzz tests for the function "flashActionByCreditor" of contract "AccountV1".
 */
contract FlashActionByCreditor_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test, Permit2Fixture {
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

    function testFuzz_Revert_flashActionByCreditor_NonCreditor(address sender, address creditor)
        public
        notTestContracts(sender)
    {
        vm.assume(sender != creditor);

        vm.prank(users.accountOwner);
        accountExtension.setCreditor(creditor);

        vm.startPrank(sender);
        vm.expectRevert(AccountErrors.OnlyCreditor.selector);
        accountExtension.flashActionByCreditor(address(action), new bytes(0));
        vm.stopPrank();
    }

    function testFuzz_Success_flashActionByCreditor(
        uint128 debtAmount,
        uint32 fixedLiquidationCost,
        bytes calldata signature,
        uint32 time
    ) public {
        vm.startPrank(users.accountOwner);
        accountNotInitialised.setFixedLiquidationCost(fixedLiquidationCost);
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
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

        bytes memory actionTargetData = abi.encode(assetDataIn, to, data);
        bytes memory callData =
            abi.encode(assetDataOut, transferFromOwner, tokenPermissions, signatureStack, actionTargetData);

        // Deposit token1 in account first
        depositERC20InAccount(
            mockERC20.token1, token1AmountForAction, users.accountOwner, address(accountNotInitialised)
        );

        // Assert the account has no TOKEN2 balance initially
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) == 0);

        vm.warp(time);

        // Call flashActionByCreditor() on Account
        vm.prank(address(creditorStable1));
        uint256 version = accountNotInitialised.flashActionByCreditor(address(action), callData);

        // Assert that the Account now has a balance of TOKEN2
        assert(mockERC20.token2.balanceOf(address(accountNotInitialised)) > 0);

        // Then: The action is successful
        assertEq(version, 1);

        // And: lastActionTimestamp is updated.
        assertEq(accountNotInitialised.lastActionTimestamp(), time);
    }
}
