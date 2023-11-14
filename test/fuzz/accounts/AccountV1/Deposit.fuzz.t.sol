/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

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
        vm.expectRevert("A: Only Owner");
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_deposit_tooManyAssets(uint8 arrLength) public {
        vm.assume(arrLength > accountExtension.ASSET_LIMIT() && arrLength < 50);

        address[] memory assetAddresses = new address[](arrLength);

        uint256[] memory assetIds = new uint256[](arrLength);

        uint256[] memory assetAmounts = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts,) = generateERC721DepositList(arrLength);

        approveAllAssets();

        vm.prank(users.accountOwner);
        vm.expectRevert("A_D: Too many assets");
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
        vm.expectRevert("A_D: Too many assets");
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_deposit_LengthOfListDoesNotMatch(uint8 addrLen, uint8 idLen, uint8 amountLen) public {
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
        vm.expectRevert("MR_BPD: LENGTH_MISMATCH");
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_ERC20WithId(uint256 id, uint128 amount) public {
        // Given: "exposure" is strictly smaller as "maxExposure".
        amount = uint128(bound(amount, 1, type(uint128).max - 1));
        id = bound(id, 1, type(uint256).max);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_D: ERC20 Id");
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_ERC721WithAmount(uint8 id, uint128 amount) public {
        amount = uint128(bound(amount, 2, type(uint128).max));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_D: ERC721 amount");
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_UnknownAsset(address asset, uint256 id, uint256 amount) public {
        vm.assume(asset != address(mockERC20.stable1));
        vm.assume(asset != address(mockERC20.stable2));
        vm.assume(asset != address(mockERC20.token1));
        vm.assume(asset != address(mockERC20.token2));
        vm.assume(asset != address(mockERC721.nft1));
        vm.assume(asset != address(mockERC1155.sft1));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = id;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(users.accountOwner);
        vm.expectRevert();
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_UnknownAssetType(uint96 assetType) public {
        vm.assume(assetType >= 3);

        mainRegistryExtension.setAssetType(address(mockERC20.token1), assetType);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_D: Unknown asset type");
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
        assetAmounts[1] = 1; // NFT amounts must be 1 in Asset Module.
        assetAmounts[2] = 0;

        mintDepositAssets(0, erc721Id, 0);
        approveAllAssets();

        vm.prank(users.accountOwner);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);

        // Then: Asset arrays are properly updated.
        (uint256 erc20Length, uint256 erc721Length,, uint256 erc1155Length) = accountExtension.getLengths();
        assertEq(erc20Length, 0);
        assertEq(
            accountExtension.erc20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.erc20Balances(address(mockERC20.token1)), 0);
        assertEq(erc721Length, 1);
        assertEq(accountExtension.erc721Stored(0), address(mockERC721.nft1));
        assertEq(accountExtension.erc721TokenIds(0), erc721Id);

        assertEq(erc1155Length, 0);

        assertEq(
            accountExtension.erc1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(accountExtension.erc1155Balances(address(mockERC1155.sft1), 1), 0);
    }

    function testFuzz_Success_deposit_NonZeroAmounts(
        uint128 erc20InitialAmount,
        uint128 erc20DepositAmount,
        uint8 erc721Id1,
        uint8 erc721Id2,
        uint128 erc1155InitialAmount,
        uint128 erc1155DepositAmount
    ) public {
        // Given: "exposure" is strictly smaller as "maxExposure".
        erc20InitialAmount = uint128(bound(erc20InitialAmount, 0, type(uint128).max - 1));
        erc20DepositAmount = uint128(bound(erc20DepositAmount, 0, type(uint128).max - erc20InitialAmount - 1));
        vm.assume(erc721Id1 != erc721Id2);
        erc1155InitialAmount = uint128(bound(erc1155InitialAmount, 0, type(uint128).max - 1));
        erc1155DepositAmount = uint128(bound(erc1155DepositAmount, 0, type(uint128).max - erc1155InitialAmount - 1));
        // And: total deposit amounts are bigger as zero.
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
            accountExtension.erc20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.erc20Balances(address(mockERC20.token1)), erc20InitialAmount + erc20DepositAmount);

        assertEq(erc721Length, 2);
        assertEq(accountExtension.erc721Stored(0), address(mockERC721.nft1));
        assertEq(accountExtension.erc721Stored(1), address(mockERC721.nft1));
        assertEq(accountExtension.erc721TokenIds(0), erc721Id1);
        assertEq(accountExtension.erc721TokenIds(1), erc721Id2);

        assertEq(erc1155Length, 1);
        assertEq(accountExtension.erc1155Stored(0), address(mockERC1155.sft1));
        assertEq(accountExtension.erc1155TokenIds(0), 1);
        assertEq(
            accountExtension.erc1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(
            accountExtension.erc1155Balances(address(mockERC1155.sft1), 1), erc1155InitialAmount + erc1155DepositAmount
        );
    }
}
