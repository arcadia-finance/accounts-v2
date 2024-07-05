/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1Extension } from "../../../../utils/extensions/AccountV1Extension.sol";
import { AccountSpotExtension } from "../../../../utils/extensions/AccountSpotExtension.sol";
import { Constants } from "../../../Fuzz.t.sol";
import { SpotToMarginMigrator } from "./_SpotToMarginMigrator.fuzz.t.sol";
import { SpotToMarginMigrator_Fuzz_Test } from "./_SpotToMarginMigrator.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "upgradeAccount" of contract "SpotToMarginMigrator".
 */
contract UpgradeAccount_SpotToMarginMigrator_Fuzz_Test is SpotToMarginMigrator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        SpotToMarginMigrator_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_revert_upgradeAccount_notOwner(address notOwner) public {
        // Given : Caller is not the Account owner
        vm.assume(notOwner != accountSpot.owner());

        bytes32[] memory proofs;
        address[] memory assets;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        // When : Calling upgradeAccount
        // Then : It should revert
        vm.startPrank(notOwner);
        vm.expectRevert(SpotToMarginMigrator.NotOwner.selector);
        spotToMarginMigrator.upgradeAccount(
            address(accountSpot), address(0), 1, proofs, assets, assetIds, assetAmounts, assetTypes
        );
        vm.stopPrank();
    }

    function testFuzz_revert_upgradeAccount_CreditorIsZeroAddress() public {
        bytes32[] memory proofs;
        address[] memory assets;
        uint256[] memory assetIds;
        uint256[] memory assetAmounts;
        uint256[] memory assetTypes;

        // When : Calling upgradeAccount
        // Then : It should revert
        vm.startPrank(users.accountOwner);
        vm.expectRevert(SpotToMarginMigrator.CreditorNotValid.selector);
        spotToMarginMigrator.upgradeAccount(
            address(accountSpot), address(0), 1, proofs, assets, assetIds, assetAmounts, assetTypes
        );
        vm.stopPrank();
    }

    function testFuzz_success_upgradeAccount(uint112 erc20Amount, uint8 erc721Id, uint112 erc1155Amount) public {
        // Given: "exposure" is strictly smaller than "maxExposure" and amount is bigger than 0.
        erc20Amount = uint112(bound(erc20Amount, 1, type(uint112).max - 1));
        erc1155Amount = uint112(bound(erc1155Amount, 1, type(uint112).max - 1));

        // And : Spot Account has assets
        mintDepositAssets(erc20Amount, erc721Id, erc1155Amount);

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof2To1;

        address[] memory assets = new address[](3);
        assets[0] = address(mockERC20.token1);
        assets[1] = address(mockERC721.nft1);
        assets[2] = address(mockERC1155.sft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = erc721Id;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = erc20Amount;
        assetAmounts[1] = 1;
        assetAmounts[2] = erc1155Amount;

        uint256[] memory assetTypes = new uint256[](3);
        assetTypes[0] = 1;
        assetTypes[1] = 2;
        assetTypes[2] = 3;

        // When : Calling upgradeAccount
        vm.startPrank(users.accountOwner);
        factory.approve(address(spotToMarginMigrator), factory.accountIndex(address(accountSpot)));
        spotToMarginMigrator.upgradeAccount(
            address(accountSpot), address(creditorStable1), 1, proofs, assets, assetIds, assetAmounts, assetTypes
        );
        vm.stopPrank();

        // Then : It should return the correct values
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
