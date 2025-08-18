/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Gas_Test } from "../Gas.t.sol";
import { AccountV3 } from "../../../src/accounts/AccountV3.sol";

/**
 * @notice Fuzz tests for the function "closeMarginAccount" of contract "AccountV3".
 */
contract Deposits_TrippleERC20_Gas_Test is Gas_Test {
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
        newAccount = factory.createAccount(1_000_000, 0, address(creditorStable1));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testGas_Deposit_ERC20_Tripple() public {
        vm.pauseGasMetering();
        (address[] memory assets, uint256[] memory ids, uint256[] memory amounts, AccountV3 account) =
            prepare_deposit_tripple_erc20(newAccount);
        vm.resumeGasMetering();
        vm.prank(users.accountOwner);
        account.deposit(assets, ids, amounts);
    }

    function testGas_Value_ERC20_Tripple() public {
        vm.pauseGasMetering();
        (address[] memory assets, uint256[] memory ids, uint256[] memory amounts, AccountV3 account) =
            prepare_deposit_tripple_erc20(newAccount);
        vm.prank(users.accountOwner);
        account.deposit(assets, ids, amounts);
        vm.resumeGasMetering();

        account.getAccountValue(address(mockERC20.stable1));
    }

    function testGas_GenerateAssetData_ERC20_Tripple() public {
        vm.pauseGasMetering();
        (address[] memory assets, uint256[] memory ids, uint256[] memory amounts, AccountV3 account) =
            prepare_deposit_tripple_erc20(newAccount);
        vm.prank(users.accountOwner);
        account.deposit(assets, ids, amounts);
        vm.resumeGasMetering();

        account.generateAssetData();
    }

    function testGas_Withdraw_ERC20_Tripple() public {
        vm.pauseGasMetering();
        (address[] memory assets, uint256[] memory ids, uint256[] memory amounts, AccountV3 account) =
            prepare_deposit_tripple_erc20(newAccount);
        vm.prank(users.accountOwner);
        account.deposit(assets, ids, amounts);
        vm.resumeGasMetering();

        vm.prank(users.accountOwner);
        account.withdraw(assets, ids, amounts);
    }
}
