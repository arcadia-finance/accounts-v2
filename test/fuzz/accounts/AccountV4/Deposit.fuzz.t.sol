/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV4 } from "../../../../src/accounts/AccountV4.sol";
import { AccountV4_Fuzz_Test } from "./_AccountV4.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "deposit" of contract "AccountV4".
 */
contract Deposit_AccountV4_Fuzz_Test is AccountV4_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV4_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_deposit_NonOwner(
        address nonOwner,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) public {
        // Given : When caller is not the Account owner
        vm.assume(nonOwner != users.accountOwner);

        // When : Calling deposit
        // Then : It should revert
        vm.prank(nonOwner);
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        accountSpot.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testFuzz_Revert_deposit_Reentered(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) public {
        // Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        // Should revert if the Account is reentered.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountsGuard.Reentered.selector);
        accountSpot.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_UnknownAssetType(uint96 assetType) public {
        // Given : assetType is > 3
        vm.assume(assetType > 3);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = assetType;

        // When : Calling deposit
        // Then : It should revert
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.UnknownAssetType.selector);
        accountSpot.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testFuzz_Success_deposit(uint112 erc20Amount, uint8 erc721Id, uint112 erc1155Amount) public {
        // Given: Assets to deposit
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC721.nft1);
        assetAddresses[2] = address(mockERC1155.sft1);

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

        // And : Assets are minted to accountOwner
        mintDepositAssets(erc20Amount, erc721Id, erc1155Amount, users.accountOwner);

        // And : Assets are approved for deposit
        vm.startPrank(users.accountOwner);
        mockERC20.token1.approve(address(accountSpot), type(uint256).max);
        mockERC721.nft1.setApprovalForAll(address(accountSpot), true);
        mockERC1155.sft1.setApprovalForAll(address(accountSpot), true);
        vm.stopPrank();

        // When: Assets are deposited into spot Account
        // Then: Correct events are emitted.
        vm.expectEmit(address(accountSpot));
        emit AccountV4.Transfers(
            users.accountOwner, address(accountSpot), assetAddresses, assetIds, assetAmounts, assetTypes
        );
        vm.prank(users.accountOwner);
        accountSpot.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        // And : It should return the correct balances
        assertEq(mockERC20.token1.balanceOf(address(accountSpot)), erc20Amount);
        assertEq(mockERC721.nft1.ownerOf(erc721Id), address(accountSpot));
        assertEq(mockERC1155.sft1.balanceOf(address(accountSpot), 1), erc1155Amount);
    }

    function testFuzz_Success_deposit_NativeEth(uint112 amount) public {
        // Given: Owner has enough balance.
        vm.deal(users.accountOwner, amount);

        // When: Native ETH is deposited into spot Account.
        vm.prank(users.accountOwner);
        accountSpot.deposit{ value: amount }(new address[](0), new uint256[](0), new uint256[](0), new uint256[](0));

        // Then : It should return the correct balance.
        assertEq(address(accountSpot).balance, amount);
    }
}
