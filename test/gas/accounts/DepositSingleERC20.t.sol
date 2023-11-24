/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Gas_Test } from "../Gas.t.sol";
import { AccountV1 } from "../../../src/accounts/AccountV1.sol";

/**
 * @notice Fuzz tests for the function "closeMarginAccount" of contract "AccountV1".
 */
contract Deposits_SingleERC20_Gas_Test is Gas_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */
    address newAccount;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Gas_Test.setUp();
        vm.prank(users.accountOwner);
        newAccount = factory.createAccount(1_000_000, 0, address(mockERC20.stable1), address(creditorStable1));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testGas_Deposit_ERC20_Single() public {
        vm.pauseGasMetering();
        (address[] memory assets, uint256[] memory ids, uint256[] memory amounts, AccountV1 account) =
            prepare_deposit_single_erc20(newAccount);
        vm.resumeGasMetering();
        vm.prank(users.accountOwner);
        account.deposit(assets, ids, amounts);
    }
}
