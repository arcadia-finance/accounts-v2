/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { stdError } from "../../../../../lib/forge-std/src/StdError.sol";
import { StdStorage, stdStorage } from "../../../../../lib/forge-std/src/Test.sol";

import { AccountExtension } from "../../../utils/Extensions.sol";
import { RiskConstants } from "../../../../utils/RiskConstants.sol";

/**
 * @notice Fuzz tests for the "withdraw" of contract "AccountV1".
 */
contract Withdraw_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

        // Given: Trusted Creditor is set.
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
        vm.expectRevert("A: Only Owner");
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
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
        vm.expectRevert("MR_BPW: LENGTH_MISMATCH");
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_UnknownAssetType(uint96 assetType) public {
        vm.assume(assetType >= 3);

        mainRegistryExtension.setAssetType(address(mockERC20.token1), assetType);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_W: Unknown asset type");
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_MoreThanMaxExposure(uint256 amountWithdraw, uint128 maxExposure) public {
        vm.assume(amountWithdraw > maxExposure);
        vm.prank(users.creatorAddress);
        erc20PricingModule.setExposureOfAsset(address(mockERC20.token1), maxExposure);

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
        // Then: Transaction should revert with "A_W721: Unknown asset".
        assetIds[0] = 101;
        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_W721: Unknown asset");
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_UnknownAsset_NotOneERC721Deposited(uint8 arrLength) public {
        // Given: two ERC721.
        mockERC721.nft1.mint(users.accountOwner, 100);
        mockERC721.nft1.mint(users.accountOwner, 101);

        // Given: At least one nft of same collection is deposited in other account.
        // (otherwise processWithdrawal underflows when arrLength is 0: account didn't deposit any nfts yet).
        AccountExtension account2 = new AccountExtension();
        account2.initialize(users.accountOwner, address(mainRegistryExtension), address(mockERC20.stable1), address(0));
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
        // Then: Transaction should revert with "A_W721: Unknown asset".
        assetAddresses = new address[](1);
        assetIds = new uint256[](1);
        assetAmounts = new uint256[](1);
        assetAddresses[0] = address(mockERC721.nft1);
        assetIds[0] = 101;
        assetAmounts[0] = 1;
        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_W721: Unknown asset");
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_WithDebt_UnsufficientCollateral(
        uint256 debt,
        uint256 collateralValueInitial,
        uint256 collateralValueDecrease,
        uint256 fixedLiquidationCost
    ) public {
        // Test-case: With debt.
        debt = bound(debt, 1, type(uint256).max);

        // No overflow of Used Margin.
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint256).max - debt);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        uint256 usedMargin = debt + fixedLiquidationCost;

        // No overflow riskmodule
        collateralValueInitial = bound(collateralValueInitial, 0, type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT);
        // No underflow Withdrawal.
        collateralValueDecrease = bound(collateralValueDecrease, 0, collateralValueInitial);

        // test-case: Insufficient collateralValue after withdrawal.
        vm.assume(collateralValueInitial - collateralValueDecrease < usedMargin);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        trustedCreditor.setOpenPosition(address(accountExtension), debt);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValueInitial);

        // When: "accountOwner" withdraws assets.
        // Then: Transaction should revert with "A_W721: Unknown asset".
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.stable1);
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = collateralValueDecrease;
        vm.prank(users.accountOwner);
        vm.expectRevert("A_W: Account Unhealthy");
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_withdraw_NoDebt_FullWithdrawal(uint128 erc20Amount, uint8 erc721Id, uint128 erc1155Amount)
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
            accountExtension.erc20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.erc20Balances(address(mockERC20.token1)), 0);
        assertEq(mockERC20.token1.balanceOf(address(users.accountOwner)), erc20Amount);

        assertEq(erc721Length, 0);

        assertEq(erc1155Length, 0);
        assertEq(
            accountExtension.erc1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(accountExtension.erc1155Balances(address(mockERC1155.sft1), 1), 0);
        assertEq(mockERC1155.sft1.balanceOf(address(users.accountOwner), 1), erc1155Amount);
    }

    function testFuzz_Success_withdraw_NoDebt_PartialWithdrawal(
        uint128 erc20InitialAmount,
        uint128 erc20WithdrawAmount,
        uint8 erc721Id,
        uint128 erc1155InitialAmount,
        uint128 erc1155WithdrawAmount
    ) public {
        // Given: total deposit amounts are bigger as zero.
        vm.assume(erc20InitialAmount > 0);
        vm.assume(erc1155InitialAmount > 0);
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

        vm.prank(users.accountOwner);
        accountExtension.withdraw(assetAddresses, assetIds, assetAmounts);

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();

        assertEq(erc20Length, 1);
        assertEq(
            accountExtension.erc20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.erc20Balances(address(mockERC20.token1)), erc20InitialAmount - erc20WithdrawAmount);
        assertEq(mockERC20.token1.balanceOf(address(users.accountOwner)), erc20WithdrawAmount);

        assertEq(erc721Length, 1);
        assertEq(accountExtension.erc721Stored(0), address(mockERC721.nft1));
        assertEq(accountExtension.erc721TokenIds(0), erc721Id);

        assertEq(erc1155Length, 1);
        assertEq(accountExtension.erc1155Stored(0), address(mockERC1155.sft1));
        assertEq(accountExtension.erc1155TokenIds(0), 1);
        assertEq(
            accountExtension.erc1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(
            accountExtension.erc1155Balances(address(mockERC1155.sft1), 1), erc1155InitialAmount - erc1155WithdrawAmount
        );
        assertEq(mockERC1155.sft1.balanceOf(address(users.accountOwner), 1), erc1155WithdrawAmount);
    }

    function testFuzz_Success_withdraw_WithDebt(
        uint256 debt,
        uint256 collateralValueInitial,
        uint256 collateralValueDecrease,
        uint256 fixedLiquidationCost
    ) public {
        // Test-case: With debt.
        debt = bound(debt, 1, type(uint256).max);

        // No overflow of Used Margin.
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint256).max - debt);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        uint256 usedMargin = debt + fixedLiquidationCost;

        // No overflow riskmodule
        collateralValueInitial = bound(collateralValueInitial, 0, type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT);
        // No underflow Withdrawal.
        collateralValueDecrease = bound(collateralValueDecrease, 0, collateralValueInitial);

        // test-case: Insufficient collateralValue after withdrawal.
        vm.assume(collateralValueInitial - collateralValueDecrease >= usedMargin);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        trustedCreditor.setOpenPosition(address(accountExtension), debt);

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
            accountExtension.erc20Balances(address(mockERC20.stable1)),
            mockERC20.stable1.balanceOf(address(accountExtension))
        );
        assertEq(
            accountExtension.erc20Balances(address(mockERC20.stable1)), collateralValueInitial - collateralValueDecrease
        );
        assertEq(mockERC20.stable1.balanceOf(address(users.accountOwner)), collateralValueDecrease);
    }
}
