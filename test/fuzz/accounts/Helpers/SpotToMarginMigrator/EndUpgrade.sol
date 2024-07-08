/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1Extension } from "../../../../utils/extensions/AccountV1Extension.sol";
import { AccountSpotExtension } from "../../../../utils/extensions/AccountSpotExtension.sol";
import { Constants } from "../../../Fuzz.t.sol";
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

    function testFuzz_revert_endUpgrade_NoOngoingUpgrade(
        address notOwner,
        uint112 erc20Amount,
        uint8 erc721Id,
        uint112 erc1155Amount
    ) public {
        // Given : An Account owner initiates an upgrade
        // And: "exposure" is strictly smaller than "maxExposure" and amount is bigger than 0.
        erc20Amount = uint112(bound(erc20Amount, 1, type(uint112).max - 1));
        erc1155Amount = uint112(bound(erc1155Amount, 1, type(uint112).max - 1));

        // And : Spot Account has assets
        mintDepositAssets(erc20Amount, erc721Id, erc1155Amount);

        // And : Account owner initiates an upgrade
        upgradeAccount(erc20Amount, erc721Id, erc1155Amount, address(creditorStable1));

        // When : Calling upgradeAccount() from a user having no ongoing Account upgrade
        // Then : It should revert
        vm.startPrank(notOwner);
        vm.expectRevert(SpotToMarginMigrator.NoOngoingUpgrade.selector);
        spotToMarginMigrator.endUpgrade();
        vm.stopPrank();
    }

    function testFuzz_success_endUpgrade(uint112 erc20Amount, uint8 erc721Id, uint112 erc1155Amount) public {
        // Given: "exposure" is strictly smaller than "maxExposure" and amount is bigger than 0.
        erc20Amount = uint112(bound(erc20Amount, 1, type(uint112).max - 1));
        erc1155Amount = uint112(bound(erc1155Amount, 1, type(uint112).max - 1));

        // And : Spot Account has assets
        mintDepositAssets(erc20Amount, erc721Id, erc1155Amount);

        // When : Calling upgradeAccount()
        upgradeAccount(erc20Amount, erc721Id, erc1155Amount, address(creditorStable1));

        // Then : It should return the correct values
        assertEq(spotToMarginMigrator.getAccountOwnedBy(users.accountOwner), address(accountSpot));
        assertEq(factory.ownerOfAccount(address(accountSpot)), address(spotToMarginMigrator));
        assertEq(accountSpot.ACCOUNT_VERSION(), 1);
        assertEq(accountSpot.creditor(), address(creditorStable1));
        assertEq(accountSpot.registry(), address(registry));
        assertEq(accountSpot.numeraire(), address(mockERC20.stable1));
        assertEq(accountSpot.minimumMargin(), Constants.initLiquidationCost);
        assertEq(accountSpot.liquidator(), Constants.initLiquidator);
        assertEq(accountSpot.erc20Balances(address(mockERC20.token1)), erc20Amount);
        assertEq(accountSpot.erc1155Balances(address(mockERC1155.sft1), 1), erc1155Amount);
        assertEq(AccountV1Extension(address(accountSpot)).isAccountUnhealthy(), false);
        assertEq(AccountV1Extension(address(accountSpot)).getERC721Stored(0), address(mockERC721.nft1));
        assertEq(AccountV1Extension(address(accountSpot)).getERC721TokenIds(0), erc721Id);
    }
}
