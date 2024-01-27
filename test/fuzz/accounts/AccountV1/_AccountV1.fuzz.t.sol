/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

import { AccountExtension } from "../../../utils/Extensions.sol";
import { ActionMultiCall } from "../../../../src/actions/MultiCall.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { MultiActionMock } from "../../../utils/mocks/actions/MultiActionMock.sol";
import { AccountErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Common logic needed by all "AccountV1" fuzz tests.
 */
abstract contract AccountV1_Fuzz_Test is Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountExtension internal accountExtension;
    MultiActionMock internal multiActionMock;
    ActionMultiCall internal action;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy Account.
        accountExtension = new AccountExtension(address(factory));

        // Initiate Account (set owner and numeraire).
        accountExtension.initialize(users.accountOwner, address(registryExtension), address(creditorStable1));

        // Set account in factory.
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension))
            .checked_write(true);

        // Initiate Reentrancy guard.
        accountExtension.setLocked(1);
    }

    /* ///////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function openMarginAccount() internal {
        vm.startPrank(users.accountOwner);
        accountExtension.closeMarginAccount();
        accountExtension.openMarginAccount(address(creditorStable1));
        vm.stopPrank();
    }

    function mintDepositAssets(uint256 erc20Amount, uint8 erc721Id, uint256 erc1155Amount) internal {
        vm.startPrank(users.tokenCreatorAddress);
        mockERC20.token1.mint(users.accountOwner, erc20Amount);
        mockERC721.nft1.mint(users.accountOwner, erc721Id);
        mockERC1155.sft1.mint(users.accountOwner, 1, erc1155Amount);
        vm.stopPrank();
    }

    function approveAllAssets() internal {
        vm.startPrank(users.accountOwner);
        mockERC20.stable1.approve(address(accountExtension), type(uint256).max);
        mockERC20.stable2.approve(address(accountExtension), type(uint256).max);
        mockERC20.token1.approve(address(accountExtension), type(uint256).max);
        mockERC20.token2.approve(address(accountExtension), type(uint256).max);
        mockERC721.nft1.setApprovalForAll(address(accountExtension), true);
        mockERC1155.sft1.setApprovalForAll(address(accountExtension), true);
        vm.stopPrank();
    }

    function depositERC20InAccount(ERC20Mock token, uint256 amount, address sender, address accountExtension_)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(users.tokenCreatorAddress);
        token.mint(sender, amount);

        vm.startPrank(sender);
        token.approve(accountExtension_, amount);
        AccountExtension(accountExtension_).deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function generateERC721DepositList(uint8 length)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](length);
        assetIds = new uint256[](length);
        assetAmounts = new uint256[](length);
        assetTypes = new uint256[](length);

        uint256 id = 10;
        for (uint256 i; i < length; ++i) {
            vm.prank(users.tokenCreatorAddress);
            mockERC721.nft1.mint(users.accountOwner, id);
            assetAddresses[i] = address(mockERC721.nft1);
            assetIds[i] = id;
            assetAmounts[i] = 1;
            assetTypes[i] = 1;
            ++id;
        }
    }
}
