/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../fuzz/Fuzz.t.sol";
import { AccountV1 } from "../../src/accounts/AccountV1.sol";

/// @notice Common logic needed by all gas tests.
abstract contract Gas_Test is Fuzz_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        // We start from a full setup
        Fuzz_Test.setUp();
    }

    function prepare_deposit_single_erc20(address newAccount)
        public
        returns (address[] memory assets, uint256[] memory ids, uint256[] memory amounts, AccountV1 account)
    {
        vm.pauseGasMetering();
        account = AccountV1(newAccount);

        vm.prank(users.tokenCreatorAddress);
        mockERC20.stable1.mint(users.accountOwner, 1000 * 10 ** 18);

        vm.startPrank(users.accountOwner);
        mockERC20.stable1.approve(address(account), 1000 * 10 ** 18);

        assets = new address[](1);
        assets[0] = address(mockERC20.stable1);
        amounts = new uint256[](1);
        amounts[0] = 1000 * 10 ** 18;
        ids = new uint256[](1);

        vm.stopPrank();

        vm.resumeGasMetering();
    }

    function prepare_deposit_double_erc20(address newAccount)
        public
        returns (address[] memory assets, uint256[] memory ids, uint256[] memory amounts, AccountV1 account)
    {
        vm.pauseGasMetering();
        account = AccountV1(newAccount);

        vm.prank(users.tokenCreatorAddress);
        mockERC20.stable1.mint(users.accountOwner, 1000 * 10 ** 18);
        mockERC20.stable2.mint(users.accountOwner, 1000 * 10 ** 18);

        vm.startPrank(users.accountOwner);
        mockERC20.stable1.approve(address(account), 1000 * 10 ** 18);
        mockERC20.stable2.approve(address(account), 1000 * 10 ** 18);

        assets = new address[](2);
        assets[0] = address(mockERC20.stable1);
        assets[1] = address(mockERC20.stable2);
        amounts = new uint256[](2);
        amounts[0] = 1000 * 10 ** 18;
        amounts[1] = 1000 * 10 ** 18;
        ids = new uint256[](2);

        vm.stopPrank();

        vm.resumeGasMetering();
    }

    function prepare_deposit_tripple_erc20(address newAccount)
        public
        returns (address[] memory assets, uint256[] memory ids, uint256[] memory amounts, AccountV1 account)
    {
        vm.pauseGasMetering();
        account = AccountV1(newAccount);

        vm.prank(users.tokenCreatorAddress);
        mockERC20.stable1.mint(users.accountOwner, 1000 * 10 ** 18);
        mockERC20.stable2.mint(users.accountOwner, 1000 * 10 ** 18);
        mockERC20.token1.mint(users.accountOwner, 1000 * 10 ** 18);

        vm.startPrank(users.accountOwner);
        mockERC20.stable1.approve(address(account), 1000 * 10 ** 18);
        mockERC20.stable2.approve(address(account), 1000 * 10 ** 18);
        mockERC20.token1.approve(address(account), 1000 * 10 ** 18);

        assets = new address[](3);
        assets[0] = address(mockERC20.stable1);
        assets[1] = address(mockERC20.stable2);
        assets[2] = address(mockERC20.token1);
        amounts = new uint256[](3);
        amounts[0] = 1000 * 10 ** 18;
        amounts[1] = 1000 * 10 ** 18;
        amounts[2] = 1000 * 10 ** 18;
        ids = new uint256[](3);

        vm.stopPrank();

        vm.resumeGasMetering();
    }
}
