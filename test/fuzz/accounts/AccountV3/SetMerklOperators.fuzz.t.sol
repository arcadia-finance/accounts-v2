/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";
import { AccountV3Extension } from "../../../utils/extensions/AccountV3Extension.sol";
import { MerklFixture } from "../../../utils/fixtures/merkl/MerklFixture.f.sol";
import { OperatorMock } from "../../../utils/mocks/merkl/OperatorMock.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "setMerklOperators" of contract "AccountV3".
 */
contract SetMerklOperators_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test, MerklFixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    OperatorMock internal operator1;
    OperatorMock internal operator2;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountV3_Fuzz_Test) {
        AccountV3_Fuzz_Test.setUp();

        // Deploy Merkl.
        deployMerkl(users.owner);

        // Deploy Account.
        accountExtension = new AccountV3Extension(address(factory), address(accountsGuard), address(distributor));

        // Set account in factory.
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension))
            .checked_write(true);

        // Initiate Account (set owner and numeraire).
        vm.prank(address(factory));
        accountExtension.initialize(users.accountOwner, address(registry), address(creditorStable1));

        // Deploy Operators.
        operator1 = new OperatorMock();
        operator2 = new OperatorMock();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_setMerklOperators_NonOwner(SetMerklOperatorsParams memory params, address nonOwner)
        public
    {
        // Given: Non-owner is not the owner of the account.
        vm.assume(nonOwner != users.accountOwner);

        // When: Non-owner calls "setMerklOperators" on the Account.
        // Then: Transaction should revert with AccountErrors.OnlyOwner.selector.
        vm.prank(nonOwner);
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        setMerklOperators(params);
    }

    function testFuzz_Revert_setMerklOperators_Reentered(SetMerklOperatorsParams memory params) public {
        // Given: Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        // When: accountOwner calls "setMerklOperators" on the Account.
        // Then: Transaction should revert with AccountsGuard.OnlyReentrant.selector.
        vm.prank(users.accountOwner);
        vm.expectRevert(AccountsGuard.Reentered.selector);
        setMerklOperators(params);
    }

    function testFuzz_Revert_setMerklOperators_LengthMismatch_OperatorStatuses(TestParams memory testParams) public {
        // Given: operatorStatuses has a length that is different from operators.
        SetMerklOperatorsParams memory params = getParams(testParams);
        params.operatorStatuses = new bool[](1);

        // When: accountOwner calls "setMerklOperators" on the Account.
        // Then: Transaction should revert with AccountErrors.LengthMismatch.selector.
        vm.prank(users.accountOwner);
        vm.expectRevert(AccountErrors.LengthMismatch.selector);
        setMerklOperators(params);
    }

    function testFuzz_Revert_setMerklOperators_LengthMismatch_OperatorDatas(TestParams memory testParams) public {
        // Given: operatorDatas has a length that is different from operators.
        SetMerklOperatorsParams memory params = getParams(testParams);
        params.operatorDatas = new bytes[](1);

        // When: accountOwner calls "setMerklOperators" on the Account.
        // Then: Transaction should revert with AccountErrors.LengthMismatch.selector.
        vm.prank(users.accountOwner);
        vm.expectRevert(AccountErrors.LengthMismatch.selector);
        setMerklOperators(params);
    }

    function testFuzz_Success_setMerklOperators_StatusOffToOff(TestParams memory testParams) public {
        // Given : Operator is set to status "off".

        // When: accountOwner calls "setMerklOperators" on the Account.
        SetMerklOperatorsParams memory params = getParams(testParams);
        params.operators = new address[](1);
        params.operators[0] = address(operator1);
        params.operatorStatuses = new bool[](1);
        params.operatorStatuses[0] = false;
        params.operatorDatas = new bytes[](1);
        vm.prank(users.accountOwner);
        setMerklOperators(params);

        // Then: Operator should be set to status "off".
        assertEq(distributor.operators(address(accountExtension), address(operator1)), 0);
    }

    function testFuzz_Success_setMerklOperators_StatusOffToOn(TestParams memory testParams) public {
        // Given : Operator is set to status "off".

        // When: accountOwner calls "setMerklOperators" on the Account.
        SetMerklOperatorsParams memory params = getParams(testParams);
        params.operators = new address[](1);
        params.operators[0] = address(operator1);
        params.operatorStatuses = new bool[](1);
        params.operatorStatuses[0] = true;
        params.operatorDatas = new bytes[](1);
        // Then: A call to the distributor should be made to toggle the operator status.
        vm.expectCall(
            address(distributor),
            abi.encodeWithSelector(distributor.toggleOperator.selector, address(accountExtension), address(operator1))
        );
        vm.prank(users.accountOwner);
        setMerklOperators(params);

        // And: Operator should be set to status "off".
        assertEq(distributor.operators(address(accountExtension), address(operator1)), 1);
    }

    function testFuzz_Success_setMerklOperators_StatusOnToOff(TestParams memory testParams) public {
        // Given : Operator is set to status "off".
        vm.prank(users.owner);
        distributor.toggleOperator(address(accountExtension), address(operator1));

        // When: accountOwner calls "setMerklOperators" on the Account.
        SetMerklOperatorsParams memory params = getParams(testParams);
        params.operators = new address[](1);
        params.operators[0] = address(operator1);
        params.operatorStatuses = new bool[](1);
        params.operatorStatuses[0] = false;
        params.operatorDatas = new bytes[](1);
        // Then: A call to the distributor should be made to toggle the operator status.
        vm.expectCall(
            address(distributor),
            abi.encodeWithSelector(distributor.toggleOperator.selector, address(accountExtension), address(operator1))
        );
        vm.prank(users.accountOwner);
        setMerklOperators(params);

        // And: Operator should be set to status "off".
        assertEq(distributor.operators(address(accountExtension), address(operator1)), 0);
    }

    function testFuzz_Success_setMerklOperators_StatusOnToOn(TestParams memory testParams) public {
        // Given : Operator is set to status "off".
        vm.prank(users.owner);
        distributor.toggleOperator(address(accountExtension), address(operator1));

        // When: accountOwner calls "setMerklOperators" on the Account.
        SetMerklOperatorsParams memory params = getParams(testParams);
        params.operators = new address[](1);
        params.operators[0] = address(operator1);
        params.operatorStatuses = new bool[](1);
        params.operatorStatuses[0] = true;
        params.operatorDatas = new bytes[](1);
        vm.prank(users.accountOwner);
        setMerklOperators(params);

        // Then: Operator should be set to status "off".
        assertEq(distributor.operators(address(accountExtension), address(operator1)), 1);
    }

    function testFuzz_Success_setMerklOperators_Hook(TestParams memory testParams) public {
        // Given : Initial state.
        SetMerklOperatorsParams memory params = getParams(testParams);
        vm.startPrank(users.owner);
        if (testParams.operatorState1.currentStatus) {
            distributor.toggleOperator(address(accountExtension), address(operator1));
        }
        if (testParams.operatorState2.currentStatus) {
            distributor.toggleOperator(address(accountExtension), address(operator2));
        }
        vm.stopPrank();

        // When: accountOwner calls "setMerklOperators" on the Account.
        // Then: Hook is called of operatorData is not empty.
        if (params.operatorDatas[0].length > 0) {
            vm.expectCall(
                address(operator1),
                abi.encodeWithSelector(
                    operator1.onSetMerklOperator.selector,
                    users.accountOwner,
                    params.operatorStatuses[0],
                    params.operatorDatas[0]
                )
            );
        }
        if (params.operatorDatas[1].length > 0) {
            vm.expectCall(
                address(operator2),
                abi.encodeWithSelector(
                    operator2.onSetMerklOperator.selector,
                    users.accountOwner,
                    params.operatorStatuses[1],
                    params.operatorDatas[1]
                )
            );
        }
        vm.prank(users.accountOwner);
        setMerklOperators(params);

        // And: Claim recipient should be set.
        assertEq(distributor.claimRecipient(address(accountExtension), testParams.token1), testParams.recipient);
        assertEq(distributor.claimRecipient(address(accountExtension), testParams.token2), testParams.recipient);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    struct OperatorState {
        bool currentStatus;
        bool operatorStatus;
        bytes operatorData;
    }

    struct TestParams {
        OperatorState operatorState1;
        OperatorState operatorState2;
        address recipient;
        address token1;
        address token2;
    }

    struct SetMerklOperatorsParams {
        address[] operators;
        bool[] operatorStatuses;
        bytes[] operatorDatas;
        address recipient;
        address[] token;
    }

    function getParams(TestParams memory testParams) internal view returns (SetMerklOperatorsParams memory params) {
        params.operators = new address[](2);
        params.operators[0] = address(operator1);
        params.operators[1] = address(operator2);

        params.operatorStatuses = new bool[](2);
        params.operatorStatuses[0] = testParams.operatorState1.operatorStatus;
        params.operatorStatuses[1] = testParams.operatorState2.operatorStatus;

        params.operatorDatas = new bytes[](2);
        params.operatorDatas[0] = testParams.operatorState1.operatorData;
        params.operatorDatas[1] = testParams.operatorState2.operatorData;

        params.recipient = testParams.recipient;

        params.token = new address[](2);
        params.token[0] = testParams.token1;
        params.token[1] = testParams.token2;
    }

    function setMerklOperators(SetMerklOperatorsParams memory params) internal {
        accountExtension.setMerklOperators(
            params.operators, params.operatorStatuses, params.operatorDatas, params.recipient, params.token
        );
    }
}
