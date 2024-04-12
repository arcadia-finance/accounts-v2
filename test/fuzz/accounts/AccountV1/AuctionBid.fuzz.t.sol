/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

import { AccountV1Extension, AccountV1 } from "../../../utils/extensions/AccountV1Extension.sol";
import { AssetModuleMock } from "../../../utils/mocks/asset-modules/AssetModuleMock.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the "auctionBid" of contract "AccountV1".
 */
contract AuctionBid_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
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
        vm.expectRevert(AccountErrors.OnlyLiquidator.selector);
        accountExtension.auctionBid(assetAddresses, assetIds, assetAmounts, bidder);
    }

    function testFuzz_Revert_AuctionBuy_Reentered(
        address bidder,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        vm.prank(accountExtension.liquidator());
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountExtension.auctionBid(assetAddresses, assetIds, assetAmounts, bidder);
    }

    function testFuzz_Revert_AuctionBuy_UnknownAsset(
        address bidder,
        address asset,
        uint256 assetId,
        uint256 assetAmount
    ) public {
        vm.assume(!registryExtension.inRegistry(asset));

        // Given: An initial state of the account with assets.
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        vm.prank(accountExtension.liquidator());
        vm.expectRevert(RegistryErrors.UnknownAsset.selector);
        accountExtension.auctionBid(assetAddresses, assetIds, assetAmounts, bidder);
    }

    function testFuzz_Revert_AuctionBuy_UnknownAssetType(address bidder, uint96 assetType) public {
        vm.assume(assetType > 3);

        vm.startPrank(users.creatorAddress);
        AssetModuleMock assetModule = new AssetModuleMock(address(registryExtension), assetType);
        registryExtension.addAssetModule(address(assetModule));
        vm.stopPrank();
        registryExtension.setAssetInformation(address(mockERC20.token1), assetType, address(assetModule));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.prank(accountExtension.liquidator());
        vm.expectRevert(AccountErrors.UnknownAssetType.selector);
        accountExtension.auctionBid(assetAddresses, assetIds, assetAmounts, bidder);
    }

    function testFuzz_Revert_AuctionBuy_LengthOfListDoesNotMatch_AssetAmountsShorter(address bidder) public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](2);

        uint256[] memory assetAmounts = new uint256[](1);

        vm.prank(accountExtension.liquidator());
        vm.expectRevert(stdError.indexOOBError);
        accountExtension.auctionBid(assetAddresses, assetIds, assetAmounts, bidder);
    }

    function testFuzz_Revert_AuctionBuy_LengthOfListDoesNotMatch_AssetAmountsLonger(address bidder) public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);

        uint256[] memory assetAmounts = new uint256[](2);

        vm.prank(accountExtension.liquidator());
        vm.expectRevert(RegistryErrors.LengthMismatch.selector);
        accountExtension.auctionBid(assetAddresses, assetIds, assetAmounts, bidder);
    }

    function testFuzz_Revert_NonDepositedErc721(address bidder, uint8 erc721Id) public {
        // Mint nft directly to account without proper deposit.
        mockERC721.nft1.mint(address(accountExtension), erc721Id);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = erc721Id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.prank(accountExtension.liquidator());
        vm.expectRevert(AccountErrors.UnknownAsset.selector);
        accountExtension.auctionBid(assetAddresses, assetIds, assetAmounts, bidder);
    }

    function testFuzz_Success_AuctionBuy_PartialBuy(
        uint112 erc20InitialAmount,
        uint112 erc20WithdrawAmount,
        uint8 erc721Id,
        uint112 erc1155InitialAmount,
        uint112 erc1155WithdrawAmount
    ) public {
        // Cannot fuzz "bidder", since contracts, since it reverts when fuzzed to a contract that does not have "onERC1155Received" implemented.
        address bidder = address(978_534_679);

        // Given: total deposit amounts are bigger than zero.
        // And: "exposure" is strictly smaller than "maxExposure".
        erc20InitialAmount = uint112(bound(erc20InitialAmount, 1, type(uint112).max - 1));
        erc1155InitialAmount = uint112(bound(erc1155InitialAmount, 1, type(uint112).max - 1));
        // And: Assets don't underflow.
        erc20WithdrawAmount = uint112(bound(erc20WithdrawAmount, 0, erc20InitialAmount - 1));
        erc1155WithdrawAmount = uint112(bound(erc1155WithdrawAmount, 0, erc1155InitialAmount - 1));

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

        // When: "Liquidator" partially withdraws assets.
        assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC1155.sft1);

        assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 1;

        assetAmounts = new uint256[](2);
        assetAmounts[0] = erc20WithdrawAmount;
        assetAmounts[1] = erc1155WithdrawAmount;

        {
            vm.prank(accountExtension.liquidator());
            uint256[] memory actualAmounts = accountExtension.auctionBid(assetAddresses, assetIds, assetAmounts, bidder);
            assertEq(actualAmounts[0], erc20WithdrawAmount);
            assertEq(actualAmounts[1], erc1155WithdrawAmount);
        }

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();

        assertEq(erc20Length, 1);

        assertEq(accountExtension.getERC20Balances(address(mockERC20.token1)), erc20InitialAmount - erc20WithdrawAmount);
        assertEq(mockERC20.token1.balanceOf(bidder), erc20WithdrawAmount);

        assertEq(erc721Length, 1);
        assertEq(accountExtension.getERC721Stored(0), address(mockERC721.nft1));
        assertEq(accountExtension.getERC721TokenIds(0), erc721Id);
        assertEq(mockERC721.nft1.ownerOf(erc721Id), address(accountExtension));

        assertEq(erc1155Length, 1);
        assertEq(accountExtension.getERC1155Stored(0), address(mockERC1155.sft1));
        assertEq(accountExtension.getERC1155TokenIds(0), 1);

        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            erc1155InitialAmount - erc1155WithdrawAmount
        );
        assertEq(mockERC1155.sft1.balanceOf(bidder, 1), erc1155WithdrawAmount);
    }

    function testFuzz_Success_AuctionBuy_buyFullAccount_ExactBidAmounts(
        uint112 erc20Amount,
        uint8 erc721Id,
        uint112 erc1155Amount
    ) public {
        // Cannot fuzz "bidder", since contracts, since it reverts when fuzzed to a contract that does not have "onERC1155Received" implemented.
        address bidder = address(978_534_679);

        // Given: "exposure" is strictly smaller than "maxExposure".
        erc20Amount = uint112(bound(erc20Amount, 0, type(uint112).max - 1));
        erc1155Amount = uint112(bound(erc1155Amount, 0, type(uint112).max - 1));

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
        {
            vm.prank(accountExtension.liquidator());
            uint256[] memory actualAmounts = accountExtension.auctionBid(assetAddresses, assetIds, assetAmounts, bidder);
            assertEq(actualAmounts[0], erc20Amount);
            assertEq(actualAmounts[1], 1);
            assertEq(actualAmounts[2], erc1155Amount);
        }

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();

        assertEq(erc20Length, 0);
        assertEq(
            accountExtension.getERC20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.getERC20Balances(address(mockERC20.token1)), 0);
        assertEq(mockERC20.token1.balanceOf(bidder), erc20Amount);

        assertEq(erc721Length, 0);
        assertEq(mockERC721.nft1.ownerOf(erc721Id), bidder);

        assertEq(erc1155Length, 0);
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1), 0);
        assertEq(mockERC1155.sft1.balanceOf(bidder, 1), erc1155Amount);
    }

    function testFuzz_Success_AuctionBuy_ExceedingBidAmounts(
        uint112 erc20Amount,
        uint112 bidErc20Amount,
        uint8 erc721Id,
        uint8 bidErc721Id,
        uint112 bidErc721Amount,
        uint112 erc1155Amount,
        uint112 bidErc1155Amount,
        uint8 bidErc1155Id
    ) public {
        {
            // Add Chainlink Oracles to the Chainlink Oracles Module.
            vm.startPrank(users.creatorAddress);
            chainlinkOM.addOracle(address(mockOracles.nft2ToUsd), "NFT2", "USD", 2 days);
            chainlinkOM.addOracle(address(mockOracles.sft2ToUsd), "SFT2", "USD", 2 days);
            vm.stopPrank();

            vm.startPrank(registryExtension.owner());
            // Add NFT2 to the floorERC721AM.
            uint80[] memory oracleNft2ToUsd = new uint80[](1);
            oracleNft2ToUsd[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.nft2ToUsd)));
            floorERC721AM.addAsset(
                address(mockERC721.nft2), 0, 999, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleNft2ToUsd)
            );

            // Add ERC1155 contract to the floorERC1155AM
            uint80[] memory oracleSft2ToUsd = new uint80[](1);
            oracleSft2ToUsd[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.sft2ToUsd)));
            floorERC1155AM.addAsset(address(mockERC1155.sft2), 1, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleSft2ToUsd));
            vm.stopPrank();
        }

        // Cannot fuzz "bidder", since contracts, since it reverts when fuzzed to a contract that does not have "onERC1155Received" implemented.
        address bidder = address(978_534_679);

        // Given: "exposure" is strictly smaller than "maxExposure".
        erc20Amount = uint112(bound(erc20Amount, 0, type(uint112).max - 1));
        erc1155Amount = uint112(bound(erc1155Amount, 0, type(uint112).max - 1));

        // And: BidAmounts are greater than actual balances.
        bidErc20Amount = uint112(bound(bidErc20Amount, erc20Amount + 1, type(uint112).max));
        bidErc721Amount = uint112(bound(bidErc721Amount, 1, type(uint112).max));
        vm.assume(erc721Id != bidErc721Id);
        bidErc1155Amount = uint112(bound(bidErc1155Amount, erc1155Amount + 1, type(uint112).max));
        vm.assume(bidErc1155Id != 1);

        {
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

            address[] memory bidAssetAddresses = new address[](7);
            bidAssetAddresses[0] = address(mockERC20.token2);
            bidAssetAddresses[1] = address(mockERC20.token1);
            bidAssetAddresses[2] = address(mockERC721.nft1);
            bidAssetAddresses[3] = address(mockERC721.nft2);
            bidAssetAddresses[4] = address(mockERC1155.sft1);
            bidAssetAddresses[5] = address(mockERC1155.sft1);
            bidAssetAddresses[6] = address(mockERC1155.sft2);

            uint256[] memory bidAssetIds = new uint256[](7);
            bidAssetIds[0] = 0;
            bidAssetIds[1] = 0;
            bidAssetIds[2] = bidErc721Id;
            bidAssetIds[3] = bidErc721Id;
            bidAssetIds[4] = 1;
            bidAssetIds[5] = bidErc1155Id;
            bidAssetIds[6] = bidErc1155Id;

            uint256[] memory bidAssetAmounts = new uint256[](7);
            bidAssetAmounts[0] = bidErc20Amount;
            bidAssetAmounts[1] = bidErc20Amount;
            bidAssetAmounts[2] = bidErc721Amount;
            bidAssetAmounts[3] = bidErc721Amount;
            bidAssetAmounts[4] = bidErc1155Amount;
            bidAssetAmounts[5] = bidErc1155Amount;
            bidAssetAmounts[6] = bidErc1155Amount;

            // Mint ERC721, not deposited in Account.
            vm.startPrank(users.tokenCreatorAddress);
            mockERC721.nft1.mint(users.tokenCreatorAddress, bidErc721Id);
            mockERC721.nft2.mint(users.tokenCreatorAddress, bidErc721Id);
            vm.stopPrank();

            // When: A user Fully withdraws assets.
            {
                vm.prank(accountExtension.liquidator());
                uint256[] memory actualAmounts =
                    accountExtension.auctionBid(bidAssetAddresses, bidAssetIds, bidAssetAmounts, bidder);
                assertEq(actualAmounts[0], 0);
                assertEq(actualAmounts[1], assetAmounts[0]);
                assertEq(actualAmounts[3], 0);
                assertEq(actualAmounts[4], assetAmounts[2]);
                assertEq(actualAmounts[5], 0);
                assertEq(actualAmounts[6], 0);
            }
        }

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();

        assertEq(erc20Length, 0);
        assertEq(
            accountExtension.getERC20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.getERC20Balances(address(mockERC20.token1)), 0);
        assertEq(mockERC20.token1.balanceOf(bidder), erc20Amount);

        assertEq(erc721Length, 1);
        assertEq(mockERC721.nft1.ownerOf(erc721Id), address(accountExtension));

        assertEq(erc1155Length, 0);
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1), 0);
        assertEq(mockERC1155.sft1.balanceOf(bidder, 1), erc1155Amount);
    }
}
