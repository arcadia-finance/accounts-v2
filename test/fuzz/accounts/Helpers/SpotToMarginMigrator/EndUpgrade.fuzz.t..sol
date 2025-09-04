/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountErrors } from "../../../../../src/libraries/Errors.sol";
import { AccountV3Extension } from "../../../../utils/extensions/AccountV3Extension.sol";
import { AccountV4Extension } from "../../../../utils/extensions/AccountV4Extension.sol";
import { Constants } from "../../../../utils/Constants.sol";
import { SpotToMarginMigrator } from "../../../../../src/accounts/helpers/SpotToMarginMigrator.sol";
import { SpotToMarginMigrator_Fuzz_Test } from "./_SpotToMarginMigrator.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "endUpgrade" of contract "SpotToMarginMigrator".
 */
contract EndUpgrade_SpotToMarginMigrator_Fuzz_Test is SpotToMarginMigrator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        SpotToMarginMigrator_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_revert_endUpgrade_NoUpgradeOngoing(address caller) public {
        // Given : An Account not being upgraded.
        assertEq(spotToMarginMigrator.getOwnerOfAccount(address(accountSpot)), address(0));

        // When : Calling upgradeAccount() from a user having no ongoing Account upgrade
        // Then : It should revert
        vm.prank(caller);
        vm.expectRevert(SpotToMarginMigrator.NoUpgradeOngoing.selector);
        spotToMarginMigrator.endUpgrade(address(accountSpot));
    }

    function testFuzz_revert_endUpgrade_BeforeCoolDown(
        address caller,
        uint112 erc20Amount,
        uint8 erc721Id,
        uint112 erc1155Amount,
        uint32 time
    ) public {
        // Given: "exposure" is strictly smaller than "maxExposure" and amount is bigger than 0.
        erc20Amount = uint112(bound(erc20Amount, 1, type(uint112).max - 1));
        erc1155Amount = uint112(bound(erc1155Amount, 1, type(uint112).max - 1));

        // And : Spot Account has assets
        mintDepositAssets(erc20Amount, erc721Id, erc1155Amount);

        // And : upgradeAccount()
        upgradeAccount(erc20Amount, erc721Id, erc1155Amount, address(creditorStable1));

        // And : cool down period has not passed.
        time = uint32(bound(time, 0, accountSpot.getCoolDownPeriod()));
        vm.warp(block.timestamp + time);

        // When : calling endUpgrade()
        vm.prank(caller);
        vm.expectRevert(AccountErrors.CoolDownPeriodNotPassed.selector);
        spotToMarginMigrator.endUpgrade(address(accountSpot));
    }

    function testFuzz_success_endUpgrade(address caller, uint112 erc20Amount, uint8 erc721Id, uint112 erc1155Amount)
        public
    {
        // Given: "exposure" is strictly smaller than "maxExposure" and amount is bigger than 0.
        erc20Amount = uint112(bound(erc20Amount, 1, type(uint112).max - 1));
        erc1155Amount = uint112(bound(erc1155Amount, 1, type(uint112).max - 1));

        // And : Spot Account has assets
        mintDepositAssets(erc20Amount, erc721Id, erc1155Amount);

        // And : upgradeAccount()
        upgradeAccount(erc20Amount, erc721Id, erc1155Amount, address(creditorStable1));

        // And : cool down period has passed
        vm.warp(block.timestamp + accountSpot.getCoolDownPeriod() + 1);

        // When : calling endUpgrade()
        vm.prank(caller);
        spotToMarginMigrator.endUpgrade(address(accountSpot));

        // Then : It should return the correct values
        assertEq(factory.ownerOfAccount(address(accountSpot)), users.accountOwner);
        assertEq(spotToMarginMigrator.getOwnerOfAccount(address(accountSpot)), address(0));
    }
}
