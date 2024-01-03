/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Gas_Test } from "../Gas.t.sol";
import { AccountV1 } from "../../../src/accounts/AccountV1.sol";

/**
 * @notice Fuzz tests for the function "closeMarginAccount" of contract "AccountV1".
 */
contract GenerateAssetData_Accounts_Gas_Test is Gas_Test {
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

    function testGas_GenerateAssetData_Single_ERC20() public {
        vm.pauseGasMetering();
        AccountV1 account = AccountV1(newAccount);

        vm.prank(users.tokenCreatorAddress);
        mockERC20.stable1.mint(users.accountOwner, 1000 * 10 ** 18);

        vm.startPrank(users.accountOwner);
        mockERC20.stable1.approve(address(account), 1000 * 10 ** 18);
        address[] memory assets = new address[](1);
        assets[0] = address(mockERC20.stable1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 * 10 ** 18;
        uint256[] memory ids = new uint256[](1);
        account.deposit(assets, ids, amounts);
        vm.stopPrank();

        vm.resumeGasMetering();

        account.generateAssetData();
    }
}
