/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "skim" of contract "AccountV1".
 */
contract Skim_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
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
    function testRevert_skim_NonOwner(address nonOwner, address asset, uint256 id, uint256 type_) public {
        vm.assume(nonOwner != users.accountOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert("A_S: Only owner can skim");
        accountExtension.skim(asset, id, type_);
        vm.stopPrank();
    }

    function testSuccess_skim_Type0_NonZeroSkim(uint256 depositAmount, uint256 transferAmount) public {
        // Deposit ERC20.
        depositAmount = bound(depositAmount, 1, type(uint256).max - 1);
        transferAmount = bound(transferAmount, 1, type(uint256).max - depositAmount);

        depositERC20InAccount(mockERC20.token1, depositAmount, users.accountOwner, address(accountExtension));

        // Mint erc20 directly to account without proper deposit.
        mockERC20.token1.mint(address(accountExtension), transferAmount);

        vm.startPrank(users.accountOwner);
        // Can't check Transfer of both ERC20 and ERC721 in same test-file.
        //vm.expectEmit(true, true, true, true);
        //emit Transfer(address(accountExtension), users.accountOwner, transferAmount);
        accountExtension.skim(address(mockERC20.token1), 0, 0);
        vm.stopPrank();

        assertEq(
            accountExtension.erc20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.erc20Balances(address(mockERC20.token1)), depositAmount);
        assertEq(mockERC20.token1.balanceOf(address(users.accountOwner)), transferAmount);
    }

    function testSuccess_skim_Type0_NothingToSkim(uint256 depositAmount) public {
        // Deposit ERC20.
        depositAmount = bound(depositAmount, 1, type(uint256).max);

        depositERC20InAccount(mockERC20.token1, depositAmount, users.accountOwner, address(accountExtension));

        vm.prank(users.accountOwner);
        accountExtension.skim(address(mockERC20.token1), 0, 0);

        assertEq(
            accountExtension.erc20Balances(address(mockERC20.token1)),
            mockERC20.token1.balanceOf(address(accountExtension))
        );
        assertEq(accountExtension.erc20Balances(address(mockERC20.token1)), depositAmount);
        assertEq(mockERC20.token1.balanceOf(address(users.accountOwner)), 0);
    }

    function testSuccess_skim_Type1_NonZeroSkim(uint256 arrLength) public {
        // Deposit number of nfts.
        arrLength = bound(arrLength, 1, accountExtension.ASSET_LIMIT());

        address[] memory assetAddresses = new address[](arrLength);
        uint256[] memory assetIds = new uint256[](arrLength);
        uint256[] memory assetAmounts = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts,) = generateERC721DepositList(uint8(arrLength));
        vm.startPrank(users.accountOwner);
        mockERC721.nft1.setApprovalForAll(address(accountExtension), true);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        // Mint nft directly to account without proper deposit.
        mockERC721.nft1.mint(address(accountExtension), 100);

        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(accountExtension), users.accountOwner, 100);
        accountExtension.skim(address(mockERC721.nft1), 100, 1);
        vm.stopPrank();

        (, uint256 erc721Length,,) = accountExtension.getLengths();
        assertEq(erc721Length, arrLength);
        assertEq(mockERC721.nft1.ownerOf(100), users.accountOwner);
    }

    function testSuccess_skim_Type1_NothingToSkim(uint256 arrLength) public {
        // Deposit number of nfts.
        arrLength = bound(arrLength, 1, accountExtension.ASSET_LIMIT());

        address[] memory assetAddresses = new address[](arrLength);
        uint256[] memory assetIds = new uint256[](arrLength);
        uint256[] memory assetAmounts = new uint256[](arrLength);

        (assetAddresses, assetIds, assetAmounts,) = generateERC721DepositList(uint8(arrLength));
        vm.startPrank(users.accountOwner);
        mockERC721.nft1.setApprovalForAll(address(accountExtension), true);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        vm.prank(users.accountOwner);
        accountExtension.skim(address(mockERC721.nft1), 10, 1);

        (, uint256 erc721Length,,) = accountExtension.getLengths();
        assertEq(erc721Length, arrLength);
    }

    function testSuccess_skim_Type2_NonZeroSkim(uint256 depositAmount, uint256 transferAmount) public {
        // Deposit ERC1155.
        depositAmount = bound(depositAmount, 1, type(uint256).max - 1);
        transferAmount = bound(transferAmount, 1, type(uint256).max - depositAmount);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC1155.sft1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = depositAmount;

        mockERC1155.sft1.mint(users.accountOwner, 1, depositAmount);
        vm.startPrank(users.accountOwner);
        mockERC1155.sft1.setApprovalForAll(address(accountExtension), true);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        // Mint erc1155 directly to account without proper deposit.
        mockERC1155.sft1.mint(address(accountExtension), 1, transferAmount);

        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(accountExtension), address(accountExtension), users.accountOwner, 1, transferAmount);
        accountExtension.skim(address(mockERC1155.sft1), 1, 2);
        vm.stopPrank();

        (,,, uint256 erc1155Length) = accountExtension.getLengths();
        assertEq(erc1155Length, 1);
        assertEq(
            accountExtension.erc1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(accountExtension.erc1155Balances(address(mockERC1155.sft1), 1), depositAmount);
        assertEq(mockERC1155.sft1.balanceOf(address(users.accountOwner), 1), transferAmount);
    }

    function testSuccess_skim_Type2_NothingToSkim(uint256 depositAmount) public {
        // Deposit ERC1155.
        depositAmount = bound(depositAmount, 1, type(uint256).max);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC1155.sft1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = depositAmount;

        mockERC1155.sft1.mint(users.accountOwner, 1, depositAmount);
        vm.startPrank(users.accountOwner);
        mockERC1155.sft1.setApprovalForAll(address(accountExtension), true);
        accountExtension.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        vm.prank(users.accountOwner);
        accountExtension.skim(address(mockERC1155.sft1), 1, 2);

        (,,, uint256 erc1155Length) = accountExtension.getLengths();
        assertEq(erc1155Length, 1);
        assertEq(
            accountExtension.erc1155Balances(address(mockERC1155.sft1), 1),
            mockERC1155.sft1.balanceOf(address(accountExtension), 1)
        );
        assertEq(accountExtension.erc1155Balances(address(mockERC1155.sft1), 1), depositAmount);
        assertEq(mockERC1155.sft1.balanceOf(address(users.accountOwner), 1), 0);
    }

    function testSuccess_skim_Ether(uint256 transferAmount) public {
        uint256 balancePre = users.accountOwner.balance;

        // No overflow.
        transferAmount = bound(transferAmount, 0, type(uint256).max - balancePre);

        vm.deal(address(accountExtension), transferAmount);

        vm.prank(users.accountOwner);
        accountExtension.skim(address(0), 0, 0);

        uint256 balancePost = users.accountOwner.balance;

        assertEq(balancePost, balancePre + transferAmount);
    }
}
