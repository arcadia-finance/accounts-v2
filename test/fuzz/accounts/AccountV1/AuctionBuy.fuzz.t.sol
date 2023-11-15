/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { AccountExtension, AccountV1 } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "auctionBuy" of contract "AccountV1".
 */
contract AuctionBuy_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_AuctionBuy_nonLiquidator(
        address nonLiquidator,
        address bidder,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public {
        vm.assume(nonLiquidator != accountExtension.liquidator());

        vm.prank(nonLiquidator);
        vm.expectRevert("A: Only Liquidator");
        accountExtension.auctionBuy(assetAddresses, assetIds, assetAmounts, bidder);
    }

    function testFuzz_Success_AuctionBuy_PartialBuy(
        uint128 erc20InitialAmount,
        uint128 erc20WithdrawAmount,
        uint8 erc721Id,
        uint128 erc1155InitialAmount,
        uint128 erc1155WithdrawAmount
    ) public {
        // Cannot fuzz "bidder", since contracts, since it reverts when fuzzed to a contract that does not have "onERC1155Received" implemented.
        address bidder = address(978_534_679);

        // Given: total deposit amounts are bigger as zero.
        // And: "exposure" is strictly smaller as "maxExposure".
        erc20InitialAmount = uint128(bound(erc20InitialAmount, 1, type(uint128).max - 1));
        erc1155InitialAmount = uint128(bound(erc1155InitialAmount, 1, type(uint128).max - 1));
        // And: Assets don't underflow.
        erc20WithdrawAmount = uint128(bound(erc20WithdrawAmount, 0, erc20InitialAmount - 1));
        erc1155WithdrawAmount = uint128(bound(erc1155WithdrawAmount, 0, erc1155InitialAmount - 1));

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
        assetAmounts[0] = erc20InitialAmount;
        assetAmounts[1] = 1;
        assetAmounts[2] = erc1155InitialAmount;

        mintDepositAssets(erc20InitialAmount, erc721Id, erc1155InitialAmount);
        approveAllAssets();

        vm.prank(users.accountOwner);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);

        // When: "accountOwner" partially withdraws assets.
        assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC1155.sft1);

        assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 1;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = erc20WithdrawAmount;
        assetAmounts[1] = erc1155WithdrawAmount;

        vm.prank(accountExtension.liquidator());
        accountExtension.auctionBuy(assetAddresses, assetIds, assetAmounts, bidder);

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();

        assertEq(erc20Length, 1);

        assertEq(accountExtension.erc20Balances(address(mockERC20.token1)), erc20InitialAmount - erc20WithdrawAmount);
        assertEq(mockERC20.token1.balanceOf(bidder), erc20WithdrawAmount);

        assertEq(erc721Length, 1);
        assertEq(accountExtension.erc721Stored(0), address(mockERC721.nft1));
        assertEq(accountExtension.erc721TokenIds(0), erc721Id);

        assertEq(erc1155Length, 1);
        assertEq(accountExtension.erc1155Stored(0), address(mockERC1155.sft1));
        assertEq(accountExtension.erc1155TokenIds(0), 1);

        assertEq(
            accountExtension.erc1155Balances(address(mockERC1155.sft1), 1), erc1155InitialAmount - erc1155WithdrawAmount
        );
        assertEq(mockERC1155.sft1.balanceOf(bidder, 1), erc1155WithdrawAmount);
    }

    function testFuzz_Success_AuctionBuy_buyFullAccount(uint128 erc20Amount, uint8 erc721Id, uint128 erc1155Amount)
        public
    {
        // Cannot fuzz "bidder", since contracts, since it reverts when fuzzed to a contract that does not have "onERC1155Received" implemented.
        address bidder = address(978_534_679);

        // Given: "exposure" is strictly smaller as "maxExposure".
        erc20Amount = uint128(bound(erc20Amount, 0, type(uint128).max - 1));
        erc1155Amount = uint128(bound(erc1155Amount, 0, type(uint128).max - 1));

        // And: An initial state of the account with assets.
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

        mintDepositAssets(erc20Amount, erc721Id, erc1155Amount);
        approveAllAssets();

        vm.prank(users.accountOwner);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);

        // When: A user Fully withdraws assets.
        vm.prank(accountExtension.liquidator());
        accountExtension.auctionBuy(assetAddresses, assetIds, assetAmounts, bidder);

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();

        assertEq(erc20Length, 0);
        assertEq(
            accountExtension.erc20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.erc20Balances(address(mockERC20.token1)), 0);
        assertEq(mockERC20.token1.balanceOf(bidder), erc20Amount);

        assertEq(erc721Length, 0);

        assertEq(erc1155Length, 0);
        assertEq(
            accountExtension.erc1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(accountExtension.erc1155Balances(address(mockERC1155.sft1), 1), 0);
        assertEq(mockERC1155.sft1.balanceOf(bidder, 1), erc1155Amount);
    }
}
