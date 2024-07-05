/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountSpotExtension } from "../../../../utils/extensions/AccountSpotExtension.sol";
import { AccountV1Extension } from "../../../../utils/extensions/AccountV1Extension.sol";
import { Constants } from "../../../Fuzz.t.sol";
import { Fuzz_Test } from "../../../Fuzz.t.sol";
import { SpotToMarginMigrator } from "../../../../../src/accounts/helpers/SpotToMarginMigrator.sol";

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

    AccountV1Extension internal accountV1ExtensionLogic;
    AccountSpotExtension internal accountSpot;
    AccountSpotExtension internal accountSpotLogic;
    SpotToMarginMigrator internal spotToMarginMigrator;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy AccountV1Extension logic contract to replace with AccountV1 logic for tests
        accountV1ExtensionLogic = new AccountV1Extension(address(factory));
        bytes memory code = address(accountV1ExtensionLogic).code;
        vm.etch(address(accountV1Logic), code);

        // Deploy Migrator contract
        spotToMarginMigrator = new SpotToMarginMigrator(address(factory));

        // Deploy a new Spot Account
        accountSpotLogic = new AccountSpotExtension(address(factory));
        vm.prank(users.owner);
        factory.setNewAccountInfo(address(registry), address(accountSpotLogic), Constants.upgradeRoot1To1And2To1, "");

        vm.prank(users.accountOwner);
        address proxyAddress = factory.createAccount(1001, 2, address(0));
        accountSpot = AccountSpotExtension(proxyAddress);
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
}
