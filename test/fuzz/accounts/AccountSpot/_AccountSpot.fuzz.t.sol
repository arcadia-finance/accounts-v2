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
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Common logic needed by all "AccountSpot" fuzz tests.
 */
abstract contract AccountSpot_Fuzz_Test is Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountSpotExtension internal accountSpot;
    MultiActionMock internal multiActionMock;
    ActionMultiCall internal action;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy Account.
        accountSpot = new AccountSpotExtension(address(factory));

        // Initiate Account (set owner).
        vm.prank(address(factory));
        accountSpot.initialize(users.accountOwner, address(0), address(0));

        // Set account in factory.
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountSpot)).checked_write(
            true
        );

        // Initiate Reentrancy guard.
        accountSpot.setLocked(1);
    }

    /* ///////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function mintDepositAssets(uint256 erc20Amount, uint8 erc721Id, uint256 erc1155Amount) internal {
        vm.startPrank(users.tokenCreator);
        mockERC20.token1.mint(users.accountOwner, erc20Amount);
        mockERC721.nft1.mint(users.accountOwner, erc721Id);
        mockERC1155.sft1.mint(users.accountOwner, 1, erc1155Amount);
        vm.stopPrank();
    }

    function approveAllAssets() internal {
        vm.startPrank(users.accountOwner);
        mockERC20.stable1.approve(address(accountSpot), type(uint256).max);
        mockERC20.stable2.approve(address(accountSpot), type(uint256).max);
        mockERC20.token1.approve(address(accountSpot), type(uint256).max);
        mockERC20.token2.approve(address(accountSpot), type(uint256).max);
        mockERC721.nft1.setApprovalForAll(address(accountSpot), true);
        mockERC1155.sft1.setApprovalForAll(address(accountSpot), true);
        vm.stopPrank();
    }
}
