/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountV4Extension } from "../../../utils/extensions/AccountV4Extension.sol";
import { ActionMultiCall } from "../../../../src/actions/MultiCall.sol";
import { Constants } from "../../../utils/Constants.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { MultiActionMock } from "../../../utils/mocks/actions/MultiActionMock.sol";

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

    MultiActionMock internal multiActionMock;
    ActionMultiCall internal action;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy Account.
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

    function mintDepositAssets(uint256 erc20Amount, uint8 erc721Id, uint256 erc1155Amount, address to) internal {
        vm.startPrank(users.tokenCreator);
        mockERC20.token1.mint(to, erc20Amount);
        mockERC721.nft1.mint(to, erc721Id);
        mockERC1155.sft1.mint(to, 1, erc1155Amount);
        vm.stopPrank();
    }
}
