/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { AssetModuleMock } from "../../../utils/mocks/asset-modules/AssetModuleMock.sol";

/**
 * @notice Fuzz tests for the function "deposit" of contract "AccountV1".
 */
contract Deposit_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_deposit_NonOwner(
        address nonOwner,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public {
        vm.assume(nonOwner != users.accountOwner);

        vm.prank(nonOwner);
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_deposit_AuctionOngoing(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public {
        accountExtension.setInAuction();

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountInAuction.selector);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_Reentered(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the Account is in an auction.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_tooManyAssets(uint8 arrLength) public {
        vm.assume(arrLength > accountExtension.ASSET_LIMIT() && arrLength < 50);

        address[] memory assetAddresses = new address[](arrLength);

        uint256[] memory assetIds = new uint256[](arrLength);

        uint256[] memory assetAmounts = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts,) = generateERC721DepositList(arrLength);

        approveAllAssets();

        vm.prank(users.accountOwner);
        vm.expectRevert(AccountErrors.TooManyAssets.selector);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_deposit_tooManyAssetsNotAtOnce(uint8 arrLength, uint8 amountToken1) public {
        vm.assume(uint256(arrLength) + 1 > accountExtension.ASSET_LIMIT() && arrLength < 50);

        //deposit a single asset first
        vm.assume(amountToken1 > 0);
        depositERC20InAccount(mockERC20.token1, amountToken1, users.accountOwner, address(accountExtension));

        //then try to go over the asset limit
        address[] memory assetAddresses = new address[](arrLength);

        uint256[] memory assetIds = new uint256[](arrLength);

        uint256[] memory assetAmounts = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts,) = generateERC721DepositList(arrLength);

        approveAllAssets();

        vm.prank(users.accountOwner);
        vm.expectRevert(AccountErrors.TooManyAssets.selector);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_deposit_WithoutCreditor_LengthOfListDoesNotMatch(
        uint8 addrLen,
        uint8 idLen,
        uint8 amountLen
    ) public {
        vm.assume((addrLen != idLen && addrLen != amountLen));
        vm.assume(
            addrLen <= accountExtension.ASSET_LIMIT() && idLen <= accountExtension.ASSET_LIMIT()
                && amountLen <= accountExtension.ASSET_LIMIT()
        );

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
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_ERC20WithId(uint256 id, uint112 amount) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
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
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_ERC721WithAmount(uint8 id, uint112 amount) public {
        amount = uint112(bound(amount, 2, type(uint112).max - 1));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.InvalidERC721Amount.selector);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_WithoutCreditor_UnknownAsset(address asset, uint256 id, uint256 amount) public {
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
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_WithCreditor_UnknownAsset(address asset, uint256 id, uint256 amount) public {
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
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_UnknownAssetType(uint96 assetType) public {
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
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Success_deposit_ZeroAmounts(uint8 erc721Id) public {
        // Given: Zero amounts are deposited.
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC721.nft1);
        assetAddresses[2] = address(mockERC1155.sft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = erc721Id;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 0;
        assetAmounts[1] = 0;
        assetAmounts[2] = 0;

        mintDepositAssets(0, erc721Id, 0);
        approveAllAssets();

        vm.prank(users.accountOwner);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length, uint256 erc721TokenIdsLength, uint256 erc1155Length) =
            accountExtension.getLengths();
        assertEq(erc20Length, 0);
        assertEq(
            accountExtension.getERC20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.getERC20Balances(address(mockERC20.token1)), 0);

        assertEq(erc721Length, 0);
        assertEq(erc721TokenIdsLength, 0);

        assertEq(erc1155Length, 0);
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1), 0);
    }

    function testFuzz_Success_deposit_WithCreditor_NonZeroAmounts(
        uint112 erc20InitialAmount,
        uint112 erc20DepositAmount,
        uint8 erc721Id1,
        uint8 erc721Id2,
        uint112 erc1155InitialAmount,
        uint112 erc1155DepositAmount
    ) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        erc20InitialAmount = uint112(bound(erc20InitialAmount, 0, type(uint112).max - 1));
        erc20DepositAmount = uint112(bound(erc20DepositAmount, 0, type(uint112).max - erc20InitialAmount - 1));
        vm.assume(erc721Id1 != erc721Id2);
        erc1155InitialAmount = uint112(bound(erc1155InitialAmount, 0, type(uint112).max - 1));
        erc1155DepositAmount = uint112(bound(erc1155DepositAmount, 0, type(uint112).max - erc1155InitialAmount - 1));
        // And: total deposit amounts are bigger than zero.
        vm.assume(erc20InitialAmount + erc20DepositAmount > 0);
        vm.assume(erc1155InitialAmount + erc1155DepositAmount > 0);

        // Given: An initial state of the account with assets.
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC721.nft1);
        assetAddresses[2] = address(mockERC1155.sft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = erc721Id1;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = erc20InitialAmount;
        assetAmounts[1] = 1;
        assetAmounts[2] = erc1155InitialAmount;

        mintDepositAssets(erc20InitialAmount, erc721Id1, erc1155InitialAmount);
        approveAllAssets();

        vm.prank(users.accountOwner);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);

        // When: A user deposits additional assets.
        assetIds[1] = erc721Id2;
        assetAmounts[0] = erc20DepositAmount;
        assetAmounts[2] = erc1155DepositAmount;
        mintDepositAssets(erc20DepositAmount, erc721Id2, erc1155DepositAmount);

        vm.prank(users.accountOwner);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();

        assertEq(erc20Length, 1);
        assertEq(
            accountExtension.getERC20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.getERC20Balances(address(mockERC20.token1)), erc20InitialAmount + erc20DepositAmount);

        assertEq(erc721Length, 2);
        assertEq(accountExtension.getERC721Stored(0), address(mockERC721.nft1));
        assertEq(accountExtension.getERC721Stored(1), address(mockERC721.nft1));
        assertEq(accountExtension.getERC721TokenIds(0), erc721Id1);
        assertEq(accountExtension.getERC721TokenIds(1), erc721Id2);

        assertEq(erc1155Length, 1);
        assertEq(accountExtension.getERC1155Stored(0), address(mockERC1155.sft1));
        assertEq(accountExtension.getERC1155TokenIds(0), 1);
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            erc1155InitialAmount + erc1155DepositAmount
        );
    }

    function testFuzz_Success_deposit_WithoutCreditor_NonZeroAmounts(
        uint112 erc20InitialAmount,
        uint112 erc20DepositAmount,
        uint8 erc721Id1,
        uint8 erc721Id2,
        uint112 erc1155InitialAmount,
        uint112 erc1155DepositAmount
    ) public {
        vm.prank(users.accountOwner);
        accountExtension.closeMarginAccount();

        // Given: "exposure" is strictly smaller than "maxExposure".
        erc20InitialAmount = uint112(bound(erc20InitialAmount, 0, type(uint112).max - 1));
        erc20DepositAmount = uint112(bound(erc20DepositAmount, 0, type(uint112).max - erc20InitialAmount - 1));
        vm.assume(erc721Id1 != erc721Id2);
        erc1155InitialAmount = uint112(bound(erc1155InitialAmount, 0, type(uint112).max - 1));
        erc1155DepositAmount = uint112(bound(erc1155DepositAmount, 0, type(uint112).max - erc1155InitialAmount - 1));
        // And: total deposit amounts are bigger than zero.
        vm.assume(erc20InitialAmount + erc20DepositAmount > 0);
        vm.assume(erc1155InitialAmount + erc1155DepositAmount > 0);

        // Given: An initial state of the account with assets.
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC721.nft1);
        assetAddresses[2] = address(mockERC1155.sft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = erc721Id1;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = erc20InitialAmount;
        assetAmounts[1] = 1;
        assetAmounts[2] = erc1155InitialAmount;

        mintDepositAssets(erc20InitialAmount, erc721Id1, erc1155InitialAmount);
        approveAllAssets();

        vm.prank(users.accountOwner);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);

        // When: A user deposits additional assets.
        assetIds[1] = erc721Id2;
        assetAmounts[0] = erc20DepositAmount;
        assetAmounts[2] = erc1155DepositAmount;
        mintDepositAssets(erc20DepositAmount, erc721Id2, erc1155DepositAmount);

        vm.prank(users.accountOwner);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();

        assertEq(erc20Length, 1);
        assertEq(
            accountExtension.getERC20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.getERC20Balances(address(mockERC20.token1)), erc20InitialAmount + erc20DepositAmount);

        assertEq(erc721Length, 2);
        assertEq(accountExtension.getERC721Stored(0), address(mockERC721.nft1));
        assertEq(accountExtension.getERC721Stored(1), address(mockERC721.nft1));
        assertEq(accountExtension.getERC721TokenIds(0), erc721Id1);
        assertEq(accountExtension.getERC721TokenIds(1), erc721Id2);

        assertEq(erc1155Length, 1);
        assertEq(accountExtension.getERC1155Stored(0), address(mockERC1155.sft1));
        assertEq(accountExtension.getERC1155TokenIds(0), 1);
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(
            accountExtension.getERC1155Balances(address(mockERC1155.sft1), 1),
            erc1155InitialAmount + erc1155DepositAmount
        );
    }
}
