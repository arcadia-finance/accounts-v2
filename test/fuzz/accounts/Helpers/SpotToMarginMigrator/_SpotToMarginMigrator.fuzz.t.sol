/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountV3Extension } from "../../../../utils/extensions/AccountV3Extension.sol";
import { AccountV4Extension } from "../../../../utils/extensions/AccountV4Extension.sol";
import { Constants } from "../../../../utils/Constants.sol";
import { Fuzz_Test } from "../../../Fuzz.t.sol";
import { SpotToMarginMigratorExtension } from "../../../../utils/extensions/SpotToMarginMigratorExtension.sol";

/**
 * @notice Common logic needed by all "SpotToMarginMigrator" fuzz tests.
 */
abstract contract SpotToMarginMigrator_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountV3Extension internal accountV3ExtensionLogic;
    AccountV4Extension internal accountSpot;
    AccountV4Extension internal accountSpotLogic;
    SpotToMarginMigratorExtension internal spotToMarginMigrator;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy AccountV3Extension logic contract to replace with AccountV3 logic for tests
        accountV3ExtensionLogic = new AccountV3Extension(address(factory), address(accountsGuard), address(0));
        bytes memory code = address(accountV3ExtensionLogic).code;
        vm.etch(address(accountLogic), code);

        // Deploy Migrator contract
        spotToMarginMigrator = new SpotToMarginMigratorExtension(address(factory));

        // Deploy a new Spot Account
        accountSpotLogic = new AccountV4Extension(address(factory), address(accountsGuard), address(0));
        vm.prank(users.owner);
        factory.setNewAccountInfo(address(registry), address(accountSpotLogic), Constants.upgradeRoot3To4And4To3, "");

        vm.prank(users.accountOwner);
        address payable proxyAddress = payable(factory.createAccount(1001, 4, address(0)));
        accountSpot = AccountV4Extension(proxyAddress);
    }

    /* ///////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function mintDepositAssets(uint256 erc20Amount, uint8 erc721Id, uint256 erc1155Amount) internal {
        vm.startPrank(users.tokenCreator);
        mockERC20.token1.mint(address(accountSpot), erc20Amount);
        mockERC721.nft1.mint(address(accountSpot), erc721Id);
        mockERC1155.sft1.mint(address(accountSpot), 1, erc1155Amount);
        vm.stopPrank();
    }

    function upgradeAccount(uint112 erc20Amount, uint8 erc721Id, uint112 erc1155Amount, address creditor) public {
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof3To4;

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
            address(accountSpot), creditor, 3, proofs, assets, assetIds, assetAmounts, assetTypes
        );
        vm.stopPrank();
    }
}
