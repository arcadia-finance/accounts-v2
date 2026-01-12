/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountV4Extension } from "../../../utils/extensions/AccountV4Extension.sol";
import { ActionTargetMock } from "../../../utils/mocks/action-targets/ActionTargetMock.sol";
import { Factory } from "../../../../src/Factory.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { RouterMock } from "../../../utils/mocks/action-targets/RouterMock.sol";

/**
 * @notice Common logic needed by all "AccountV4" fuzz tests.
 */
abstract contract AccountV4_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountV4Extension internal accountSpot;
    AccountV4Extension internal accountSpotLogic;

    RouterMock internal routerMock;
    ActionTargetMock internal actionTarget;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy Account.
        accountSpotLogic = new AccountV4Extension(address(factory), address(accountsGuard), address(0));
        factory.setVersionInformation(
            4,
            Factory.VersionInformation({
                registry: address(registry), implementation: address(accountSpotLogic), data: ""
            })
        );

        vm.prank(users.accountOwner);
        address payable proxyAddress = payable(factory.createAccount(1001, 4, address(0)));
        accountSpot = AccountV4Extension(proxyAddress);
    }

    /* ///////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function mintDepositAssets(uint256 erc20Amount, uint8 erc721Id, uint256 erc1155Amount, address to) internal {
        vm.startPrank(users.tokenCreator);
        mockERC20.token1.mint(to, erc20Amount);
        mockERC721.nft1.mint(to, erc721Id);
        mockERC1155.sft1.mint(to, 1, erc1155Amount);
        vm.stopPrank();
    }
}
