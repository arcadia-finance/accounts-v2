/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { AccountSpotExtension } from "../../../utils/extensions/AccountSpotExtension.sol";
import { ActionMultiCall } from "../../../../src/actions/MultiCall.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { MultiActionMock } from "../../../utils/mocks/actions/MultiActionMock.sol";

/**
 * @notice Common logic needed by all "AccountSpot" fuzz tests.
 */
abstract contract AccountSpot_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountSpotExtension internal accountSpot;
    AccountSpotExtension internal accountSpotLogic;

    MultiActionMock internal multiActionMock;
    ActionMultiCall internal action;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy Account.
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
