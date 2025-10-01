/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountV3Extension } from "../../../utils/extensions/AccountV3Extension.sol";
import { ActionTargetMock } from "../../../utils/mocks/action-targets/ActionTargetMock.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { RouterMock } from "../../../utils/mocks/action-targets/RouterMock.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Common logic needed by all "AccountV3" fuzz tests.
 */
abstract contract AccountV3_Fuzz_Test is Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountV3Extension internal accountExtension;
    RouterMock internal routerMock;
    ActionTargetMock internal actionTarget;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy Account.
        accountExtension = new AccountV3Extension(address(factory), address(accountsGuard), address(0));

        // Set account in factory.
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension))
            .checked_write(true);

        // Initiate Account (set owner and numeraire).
        vm.prank(address(factory));
        accountExtension.initialize(users.accountOwner, address(registry), address(creditorStable1));
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
        vm.startPrank(users.tokenCreator);
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

    function depositErc20InAccount(ERC20Mock token, uint256 amount, address sender, address accountExtension_)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(users.tokenCreator);
        token.mint(sender, amount);

        vm.startPrank(sender);
        token.approve(accountExtension_, amount);
        AccountV3Extension(accountExtension_).deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function generateErc721DepositList(uint8 length)
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
            vm.prank(users.tokenCreator);
            mockERC721.nft1.mint(users.accountOwner, id);
            assetAddresses[i] = address(mockERC721.nft1);
            assetIds[i] = id;
            assetAmounts[i] = 1;
            assetTypes[i] = 2;
            ++id;
        }
    }
}
