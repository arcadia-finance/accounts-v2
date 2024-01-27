/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

import { stdError } from "../../../../lib/forge-std/src/StdError.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

import { AccountExtension } from "../../../utils/Extensions.sol";
import { AssetModuleMock } from "../../../utils/mocks/asset-modules/AssetModuleMock.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "withdraw" of contract "AccountV1".
 */
contract Withdraw_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

        // Given: Creditor is set.
        openMarginAccount();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_withdraw_NonOwner(
        address nonOwner,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public {
        vm.assume(nonOwner != users.accountOwner);

        vm.prank(nonOwner);
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_withdraw_Reentered(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the Account is in an auction.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_InAuction(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public {
        // Will set "inAuction" to true.
        accountExtension.setInAuction();

        // Should revert if the Account is in an auction.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountInAuction.selector);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_LengthOfListDoesNotMatch(uint8 addrLen, uint8 idLen, uint8 amountLen) public {
        vm.assume((addrLen != idLen && addrLen != amountLen));

        address[] memory assetAddresses = new address[](addrLen);
        for (uint256 i; i < addrLen; ++i) {
            assetAddresses[i] = address(uint160(i));
        }

        uint256[] memory assetIds = new uint256[](idLen);
        for (uint256 j; j < idLen; j++) {
            assetIds[j] = j;
        }

        uint256[] memory assetAmounts = new uint256[](amountLen);
        for (uint256 k; k < amountLen; k++) {
            assetAmounts[k] = k;
        }

        vm.startPrank(users.accountOwner);
        vm.expectRevert(RegistryErrors.LengthMismatch.selector);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_ERC20WithId(uint256 id, uint112 amount) public {
        amount = uint112(bound(amount, 1, type(uint112).max - 1));
        id = bound(id, 1, type(uint256).max);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.InvalidERC20Id.selector);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_ERC721WithAmount(uint8 id, uint112 amount) public {
        amount = uint112(bound(amount, 2, type(uint112).max - 1));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.InvalidERC721Amount.selector);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_UnknownAssetType(uint96 assetType) public {
        vm.assume(assetType >= 3);

        vm.startPrank(users.creatorAddress);
        AssetModuleMock assetModule = new AssetModuleMock(address(registryExtension), assetType);
        registryExtension.addAssetModule(address(assetModule));
        vm.stopPrank();
        registryExtension.setAssetToAssetModule(address(mockERC20.token1), address(assetModule));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.UnknownAssetType.selector);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_MoreThanMaxExposure(uint256 amountWithdraw, uint112 maxExposure) public {
        vm.assume(amountWithdraw > maxExposure);

        vm.startPrank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC20.token1), 0, maxExposure, 0, 0
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountWithdraw;

        vm.startPrank(users.accountOwner);
        vm.expectRevert(stdError.arithmeticError);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_WithoutCreditor_UnknownAsset(address asset, uint256 id, uint256 amount) public {
        vm.prank(users.accountOwner);
        accountExtension.closeMarginAccount();

        vm.assume(!registryExtension.inRegistry(asset));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(users.accountOwner);
        vm.expectRevert(bytes(""));
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_WithCreditor_UnknownAsset(address asset, uint256 id, uint256 amount) public {
        vm.assume(!registryExtension.inRegistry(asset));

        amount = bound(amount, 1, type(uint256).max);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(users.accountOwner);
        vm.expectRevert(bytes(""));
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_UnknownAsset_OneERC721Deposited() public {
        // Given: two ERC721.
        mockERC721.nft1.mint(users.accountOwner, 100);
        mockERC721.nft1.mint(users.accountOwner, 101);

        // And: "accountOwner" deposits exactly one nft.
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 100;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(users.accountOwner);
        mockERC721.nft1.approve(address(accountExtension), 100);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        // And: "accountOwner" transfers second nft directly to account without a deposit.
        vm.prank(users.accountOwner);
        mockERC721.nft1.safeTransferFrom(users.accountOwner, address(accountExtension), 101);

        // When: "accountOwner" withdraws the second nft.
        // Then: Transaction should revert with AccountErrors.UnknownAsset.selector.
        assetIds[0] = 101;
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.UnknownAsset.selector);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_UnknownAsset_NotOneERC721Deposited(uint8 arrLength) public {
        // Given: two ERC721.
        mockERC721.nft1.mint(users.accountOwner, 100);
        mockERC721.nft1.mint(users.accountOwner, 101);

        // Given: At least one nft of same collection is deposited in other account.
        // (otherwise processWithdrawal underflows when arrLength is 0: account didn't deposit any nfts yet).
        AccountExtension account2 = new AccountExtension(address(factory));
        account2.initialize(users.accountOwner, address(registryExtension), address(creditorStable1));
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(account2)).checked_write(
            true
        );

        address[] memory assetAddresses = new address[](1);
        uint256[] memory assetIds = new uint256[](1);
        uint256[] memory assetAmounts = new uint256[](1);
        assetAddresses[0] = address(mockERC721.nft1);
        assetIds[0] = 100;
        assetAmounts[0] = 1;

        vm.startPrank(users.accountOwner);
        mockERC721.nft1.approve(address(account2), 100);
        account2.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        // Given: "accountOwner" deposits a number of nfts different from 1 in first account.
        vm.assume(arrLength < accountExtension.ASSET_LIMIT());
        vm.assume(arrLength != 1);

        assetAddresses = new address[](arrLength);
        assetIds = new uint256[](arrLength);
        assetAmounts = new uint256[](arrLength);
        (assetAddresses, assetIds, assetAmounts,) = generateERC721DepositList(arrLength);
        vm.startPrank(users.accountOwner);
        mockERC721.nft1.setApprovalForAll(address(accountExtension), true);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        // And: "accountOwner" transfers a different nft directly to account without a deposit.
        vm.prank(users.accountOwner);
        mockERC721.nft1.safeTransferFrom(users.accountOwner, address(accountExtension), 101);

        // When: "accountOwner" withdraws the wrongly transferred nft.
        // Then: Transaction should revert with AccountErrors.UnknownAsset.selector.
        assetAddresses = new address[](1);
        assetIds = new uint256[](1);
        assetAmounts = new uint256[](1);
        assetAddresses[0] = address(mockERC721.nft1);
        assetIds[0] = 101;
        assetAmounts[0] = 1;
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.UnknownAsset.selector);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_WithDebt_UnsufficientCollateral(
        uint256 debt,
        uint112 collateralValueInitial,
        uint256 collateralValueDecrease,
        uint256 minimumMargin
    ) public {
        // Test-case: With debt.
        debt = bound(debt, 1, type(uint256).max);

        // No overflow of Used Margin.
        minimumMargin = bound(minimumMargin, 0, type(uint256).max - debt);
        minimumMargin = bound(minimumMargin, 0, type(uint96).max);
        uint256 usedMargin = debt + minimumMargin;

        // "exposure" is strictly smaller than "maxExposure".
        collateralValueInitial = uint112(bound(collateralValueInitial, 0, type(uint112).max - 1));

        // No underflow Withdrawal.
        collateralValueDecrease = bound(collateralValueDecrease, 0, collateralValueInitial);

        // test-case: Insufficient collateralValue after withdrawal.
        vm.assume(collateralValueInitial - collateralValueDecrease < usedMargin);

        // Set minimumMargin
        accountExtension.setMinimumMargin(uint96(minimumMargin));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), debt);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValueInitial);

        // When: "accountOwner" withdraws assets.
        // Then: Transaction should revert with AccountErrors.UnknownAsset.selector.
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.stable1);
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = collateralValueDecrease;
        vm.prank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_withdraw_NoDebt_WithoutCreditor_FullWithdrawal(
        uint112 erc20Amount,
        uint8 erc721Id,
        uint112 erc1155Amount,
        uint32 time
    ) public {
        vm.prank(users.accountOwner);
        accountExtension.closeMarginAccount();

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

        vm.warp(time);

        // When: A user Fully withdraws assets.
        vm.prank(users.accountOwner);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();

        assertEq(erc20Length, 0);
        assertEq(
            accountExtension.getERC20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.getERC20Balances(address(mockERC20.token1)), 0);
        assertEq(mockERC20.token1.balanceOf(address(users.accountOwner)), erc20Amount);

        assertEq(erc721Length, 0);

        assertEq(erc1155Length, 0);
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1), 0);
        assertEq(mockERC1155.sft1.balanceOf(address(users.accountOwner), 1), erc1155Amount);

        // And: lastActionTimestamp is updated.
        assertEq(accountExtension.lastActionTimestamp(), time);
    }

    function testFuzz_Success_withdraw_NoDebt_WithCreditor_FullWithdrawal(
        uint112 erc20Amount,
        uint8 erc721Id,
        uint112 erc1155Amount
    ) public {
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
        vm.prank(users.accountOwner);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();

        assertEq(erc20Length, 0);
        assertEq(
            accountExtension.getERC20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.getERC20Balances(address(mockERC20.token1)), 0);
        assertEq(mockERC20.token1.balanceOf(address(users.accountOwner)), erc20Amount);

        assertEq(erc721Length, 0);

        assertEq(erc1155Length, 0);
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1), 0);
        assertEq(mockERC1155.sft1.balanceOf(address(users.accountOwner), 1), erc1155Amount);
    }

    function testFuzz_Success_withdraw_NoDebt_PartialWithdrawal(
        uint112 erc20InitialAmount,
        uint112 erc20WithdrawAmount,
        uint8 erc721Id,
        uint112 erc1155InitialAmount,
        uint112 erc1155WithdrawAmount
    ) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        erc20InitialAmount = uint112(bound(erc20InitialAmount, 0, type(uint112).max - 1));
        erc1155InitialAmount = uint112(bound(erc1155InitialAmount, 0, type(uint112).max - 1));

        // And: total deposit amounts are bigger than zero.
        vm.assume(erc20InitialAmount > 0);
        vm.assume(erc1155InitialAmount > 0);
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

        vm.prank(users.accountOwner);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();

        assertEq(erc20Length, 1);
        assertEq(
            accountExtension.getERC20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.getERC20Balances(address(mockERC20.token1)), erc20InitialAmount - erc20WithdrawAmount);
        assertEq(mockERC20.token1.balanceOf(address(users.accountOwner)), erc20WithdrawAmount);

        assertEq(erc721Length, 1);
        assertEq(accountExtension.getERC721Stored(0), address(mockERC721.nft1));
        assertEq(accountExtension.getERC721TokenIds(0), erc721Id);

        assertEq(erc1155Length, 1);
        assertEq(accountExtension.getERC1155Stored(0), address(mockERC1155.sft1));
        assertEq(accountExtension.getERC1155TokenIds(0), 1);
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            erc1155InitialAmount - erc1155WithdrawAmount
        );
        assertEq(mockERC1155.sft1.balanceOf(address(users.accountOwner), 1), erc1155WithdrawAmount);
    }

    function testFuzz_Success_withdraw_ZeroAmount(uint112 erc20Amount, uint8 erc721Id, uint112 erc1155Amount) public {
        // Given: "exposure" is strictly smaller than "maxExposure" and bigger as 0.
        erc20Amount = uint112(bound(erc20Amount, 1, type(uint112).max - 1));
        erc1155Amount = uint112(bound(erc1155Amount, 1, type(uint112).max - 1));

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

        // When: A user withdraws zero amounts.
        assetAmounts = new uint256[](3);
        vm.prank(users.accountOwner);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);

        // Then: Asset arrays are not updated.
        (uint256 erc20Length, uint256 erc721Length, uint256 erc721TokenIdsLength, uint256 erc1155Length) =
            accountExtension.getLengths();

        assertEq(erc20Length, 1);
        assertEq(
            accountExtension.getERC20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.getERC20Balances(address(mockERC20.token1)), erc20Amount);

        assertEq(erc721Length, 1);
        assertEq(erc721TokenIdsLength, 1);
        assertEq(accountExtension.getERC721Stored(0), address(mockERC721.nft1));
        assertEq(accountExtension.getERC721TokenIds(0), erc721Id);

        assertEq(erc1155Length, 1);
        assertEq(accountExtension.getERC1155Stored(0), address(mockERC1155.sft1));
        assertEq(accountExtension.getERC1155TokenIds(0), 1);
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1), erc1155Amount);
    }

    function testFuzz_Success_withdraw_WithDebt(
        uint256 debt,
        uint112 collateralValueInitial,
        uint256 collateralValueDecrease,
        uint256 minimumMargin
    ) public {
        // Test-case: With debt.
        debt = bound(debt, 1, type(uint256).max);

        // No overflow of Used Margin.
        minimumMargin = bound(minimumMargin, 0, type(uint256).max - debt);
        minimumMargin = bound(minimumMargin, 0, type(uint96).max);
        uint256 usedMargin = debt + minimumMargin;

        // "exposure" is strictly smaller than "maxExposure".
        collateralValueInitial = uint112(bound(collateralValueInitial, 0, type(uint112).max - 1));

        // No underflow Withdrawal.
        collateralValueDecrease = bound(collateralValueDecrease, 0, collateralValueInitial);

        // test-case: Insufficient collateralValue after withdrawal.
        vm.assume(collateralValueInitial - collateralValueDecrease >= usedMargin);

        // Set minimumMargin
        accountExtension.setMinimumMargin(uint96(minimumMargin));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), debt);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValueInitial);

        // When: "accountOwner" withdraws assets.
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.stable1);
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = collateralValueDecrease;
        vm.prank(users.accountOwner);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length,,,) = accountExtension.getLengths();

        assertEq(erc20Length, 1);
        assertEq(
            accountExtension.getERC20Balances(address(mockERC20.stable1)),
            mockERC20.stable1.balanceOf(address(accountExtension))
        );
        assertEq(
            accountExtension.getERC20Balances(address(mockERC20.stable1)),
            collateralValueInitial - collateralValueDecrease
        );
        assertEq(mockERC20.stable1.balanceOf(address(users.accountOwner)), collateralValueDecrease);
    }
}
