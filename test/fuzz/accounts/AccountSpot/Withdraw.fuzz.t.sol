/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountSpotExtension } from "../../../utils/extensions/AccountSpotExtension.sol";
import { AccountSpot_Fuzz_Test } from "./_AccountSpot.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "withdraw" of contract "AccountSpot".
 */
contract Withdraw_AccountSpot_Fuzz_Test is AccountSpot_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountSpot_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_withdraw_NonOwner(
        address nonOwner,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) public {
        vm.assume(nonOwner != users.accountOwner);

        vm.prank(nonOwner);
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        accountSpot.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
    }

    function testFuzz_Revert_withdraw_Reentered(
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
        accountSpot.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_UnknownAssetType(uint96 assetType) public {
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
        accountSpot.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);
        vm.stopPrank();
    }

    function testFuzz_Success_withdraw(uint112 erc20Amount, uint8 erc721Id, uint112 erc1155Amount, uint32 time)
        public
    {
        // Given: An initial state of the account with assets.
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

        mintDepositAssets(erc20Amount, erc721Id, erc1155Amount);

        vm.warp(time);

        // When: A user Fully withdraws assets.
        vm.prank(users.accountOwner);
        accountSpot.withdraw(assetAddresses, assetIds, assetAmounts, assetTypes);

        assertEq(mockERC20.token1.balanceOf(address(users.accountOwner)), erc20Amount);
        assertEq(mockERC721.nft1.ownerOf(erc721Id), users.accountOwner);
        assertEq(mockERC1155.sft1.balanceOf(address(users.accountOwner), 1), erc1155Amount);
        assertEq(accountSpot.lastActionTimestamp(), time);
    }

    function testFuzz_Success_withdraw_ETH(uint112 ethAmount) public {
        // Given : Initial amount of ETH sent to the Spot Account
        ethAmount = uint112(bound(ethAmount, 1, 100 ether));
        vm.prank(users.accountOwner);
        (bool success,) = payable(address(accountSpot)).call{ value: ethAmount }("");
        assertEq(success, true);
        assertEq(address(accountSpot).balance, ethAmount);

        address[] memory assets = new address[](1);
        assets[0] = address(0);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = ethAmount;

        uint256[] memory assetTypes = new uint256[](3);
        assetTypes[0] = 0;

        uint256 initETHBalance = users.accountOwner.balance;

        // When : Trying to withdraw ETH
        vm.prank(users.accountOwner);
        accountSpot.withdraw(assets, assetIds, assetAmounts, assetTypes);

        // Then : ETH should have been received by the accountOwner
        assertEq(users.accountOwner.balance, initETHBalance + ethAmount);
    }
}
