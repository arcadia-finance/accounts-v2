/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { AccountExtension, AccountV1 } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "checkAndStartLiquidation" of contract "AccountV1".
 */
contract CheckAndStartLiquidation_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountExtension internal accountNotInitialised;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

        vm.prank(users.accountOwner);
        accountNotInitialised = new AccountExtension();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_checkAndStartLiquidation_nonLiquidator(
        address nonLiquidator
    ) public {
        // openMarginAccount() will set a liquidator on the account
        vm.startPrank(users.accountOwner);
        proxyAccount_New.openTrustedMarginAccount(address(trustedCreditor));

        vm.assume(nonLiquidator != proxyAccount_New.liquidator());
        
        vm.startPrank(nonLiquidator);
        vm.expectRevert("A: Only Liquidator");
        proxyAccount_New.checkAndStartLiquidation();
        vm.stopPrank();
    }

    function testFuzz_Revert_checkAndStartLiquidation_notLiquidatable_usedMarginSmallerThanLiquidationCost(
        uint96 fixedLiquidationCost,
        uint256 debtAmount
    ) public {
        vm.assume(debtAmount > 0);

        accountNotInitialised.setFixedLiquidationCost(fixedLiquidationCost);
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setRegistry(address(mainRegistryExtension));
        vm.prank(users.accountOwner);
        accountNotInitialised.setBaseCurrency(address(mockERC20.token1));
        accountNotInitialised.setTrustedCreditor(address(trustedCreditor));
        accountNotInitialised.setIsTrustedCreditorSet(true);

        trustedCreditor.setOpenPosition(address(accountNotInitialised), debtAmount); 

        


    }

    function testFuzz_Revert_checkAndStartLiquidation_notLiquidatable_liquidationValueGreaterThanUsedMargin(

    ) public {

    }

/*         accountNotInitialised.setFixedLiquidationCost(fixedLiquidationCost);
        accountNotInitialised.setLocked(1);
        accountNotInitialised.setOwner(users.accountOwner);
        accountNotInitialised.setRegistry(address(mainRegistryExtension));
        vm.prank(users.accountOwner);
        accountNotInitialised.setBaseCurrency(address(mockERC20.token1));
        accountNotInitialised.setTrustedCreditor(address(trustedCreditor));
        accountNotInitialised.setIsTrustedCreditorSet(true);

        trustedCreditor.setOpenPosition(address(accountNotInitialised), debtAmount); */

}