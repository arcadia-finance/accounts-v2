/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountSpotExtension } from "../../../utils/extensions/AccountSpotExtension.sol";
import { AccountSpot_Fuzz_Test } from "./_AccountSpot.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "deposit" of contract "AccountSpot".
 */
contract Deposit_AccountSpot_Fuzz_Test is AccountSpot_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountSpot_Fuzz_Test.setUp();
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
        vm.assume(nonOwner != users.accountOwner);

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
        accountSpot.setLocked(2);

        // Should revert if the Account is reentered.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountSpot.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_UnknownAssetType(uint96 assetType) public {
        vm.assume(assetType > 3);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = assetType;

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.UnknownAssetType.selector);
        accountSpot.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_InvalidERC20ID(uint96 assetId) public {
        assetId = uint96(bound(assetId, 1, type(uint96).max));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 1;

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.InvalidERC20Id.selector);
        accountSpot.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_InvalidERC721Amount(uint96 assetAmount) public {
        // Given : assetAmount is > 1
        assetAmount = uint96(bound(assetAmount, 2, type(uint96).max));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        uint256[] memory assetTypes = new uint256[](1);
        assetTypes[0] = 2;

        // When : Calling deposit
        // Then : It should revert
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.InvalidERC721Amount.selector);
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
        vm.prank(users.accountOwner);
        accountSpot.deposit(assetAddresses, assetIds, assetAmounts, assetTypes);

        // Then : It should return the correct balances
        assertEq(mockERC20.token1.balanceOf(address(accountSpot)), erc20Amount);
        assertEq(mockERC721.nft1.ownerOf(erc721Id), address(accountSpot));
        assertEq(mockERC1155.sft1.balanceOf(address(accountSpot), 1), erc1155Amount);
    }
}
