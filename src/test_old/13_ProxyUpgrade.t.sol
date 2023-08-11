/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaAccountsFixture.f.sol";

import { AccountV2 } from "../mockups/AccountV2.sol";

import { TrustedCreditorMock } from "../mockups/TrustedCreditorMock.sol";

contract AccountV2Test is DeployArcadiaAccounts {
    using stdStorage for StdStorage;

    AccountV2 private accountV2;
    address private proxyAddr2;
    address liquidator = address(8);

    TrustedCreditorMock trustedCreditor;

    struct Checks {
        bool isTrustedCreditorSet;
        uint16 accountVersion;
        address baseCurrency;
        address owner;
        address liquidator;
        address registry;
        address trustedCreditor;
        address[] assetAddresses;
        uint256[] assetIds;
        uint256[] assetAmounts;
    }

    // EVENTS
    event AccountUpgraded(address indexed accountAddress, uint16 oldVersion, uint16 indexed newVersion);

    //this is a before
    constructor() DeployArcadiaAccounts() {
        trustedCreditor = new TrustedCreditorMock();
        trustedCreditor.setBaseCurrency(address(dai));
        trustedCreditor.setLiquidator(liquidator);
    }

    //this is a before each
    function setUp() public {
        vm.startPrank(accountOwner);
        proxyAddr = factory.createAccount(
            uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)
                    )
                )
            ),
            0,
            address(0),
            address(0)
        );
        proxy = AccountV1(proxyAddr);
        proxy.openTrustedMarginAccount(address(trustedCreditor));
        dai.approve(address(proxy), type(uint256).max);

        bayc.setApprovalForAll(address(proxy), true);
        mayc.setApprovalForAll(address(proxy), true);
        dickButs.setApprovalForAll(address(proxy), true);
        interleave.setApprovalForAll(address(proxy), true);
        eth.approve(address(proxy), type(uint256).max);
        link.approve(address(proxy), type(uint256).max);
        snx.approve(address(proxy), type(uint256).max);
        safemoon.approve(address(proxy), type(uint256).max);
        dai.approve(liquidator, type(uint256).max);

        accountV2 = new AccountV2();
        vm.stopPrank();
    }

    function testSuccess_upgradeAccountVersion_StorageVariablesAfterUpgradeAreIdentical(uint128 amount) public {
        vm.assume(amount > 0);
        depositERC20InAccount(eth, amount, accountOwner);
        uint128[] memory tokenIds = new uint128[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        depositERC721InAccount(bayc, tokenIds, accountOwner);
        depositERC1155InAccount(interleave, 1, 1000, accountOwner);

        Checks memory checkBefore = createCompareStruct();

        vm.startPrank(creatorAddress);
        factory.setNewAccountInfo(address(mainRegistry), address(accountV2), Constants.upgradeRoot1To2, "");
        vm.stopPrank();

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        vm.startPrank(accountOwner);
        vm.expectEmit(true, true, true, true);
        emit AccountUpgraded(address(proxy), 1, 2);
        factory.upgradeAccountVersion(address(proxy), factory.latestAccountVersion(), proofs);
        vm.stopPrank();

        assertEq(AccountV2(proxyAddr).storageV2(), 5);

        Checks memory checkAfter = createCompareStruct();

        assertEq(keccak256(abi.encode(checkAfter)), keccak256(abi.encode(checkBefore)));
        assertEq(factory.latestAccountVersion(), proxy.ACCOUNT_VERSION());
    }

    function testRevert_upgradeAccountVersion_IncompatibleVersionWithCurrentAccount(uint128 amount) public {
        depositERC20InAccount(eth, amount, accountOwner);
        uint128[] memory tokenIds = new uint128[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        depositERC721InAccount(bayc, tokenIds, accountOwner);
        depositERC1155InAccount(interleave, 1, 1000, accountOwner);

        Checks memory checkBefore = createCompareStruct();

        vm.startPrank(creatorAddress);
        factory.setNewAccountInfo(address(mainRegistry), address(accountV2), Constants.upgradeRoot1To2, "");
        vm.stopPrank();

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        trustedCreditor.setCallResult(false);

        vm.startPrank(accountOwner);
        vm.expectRevert("FTR_UVV: Version not allowed");
        factory.upgradeAccountVersion(address(proxy), 0, proofs);
        vm.stopPrank();

        Checks memory checkAfter = createCompareStruct();

        assertEq(keccak256(abi.encode(checkAfter)), keccak256(abi.encode(checkBefore)));
    }

    function testRevert_upgradeAccountVersion_UpgradeAccountByNonOwner(address sender) public {
        vm.assume(sender != address(6));

        vm.startPrank(creatorAddress);
        factory.setNewAccountInfo(address(mainRegistry), address(accountV2), Constants.upgradeRoot1To2, "");
        vm.stopPrank();

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        vm.startPrank(sender);
        vm.expectRevert("FTRY_UVV: Only Owner");
        factory.upgradeAccountVersion(address(proxy), 2, proofs);
        vm.stopPrank();
    }

    function depositERC20InAccount(ERC20Mock token, uint128 amount, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositERC20InAccountV2(ERC20Mock token, uint128 amount, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        vm.startPrank(sender);
        accountV2.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositERC721InAccount(ERC721Mock token, uint128[] memory tokenIds, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](tokenIds.length);
        assetIds = new uint256[](tokenIds.length);
        assetAmounts = new uint256[](tokenIds.length);

        uint256 tokenIdToWorkWith;
        for (uint256 i; i < tokenIds.length; ++i) {
            tokenIdToWorkWith = tokenIds[i];
            while (token.getOwnerOf(tokenIdToWorkWith) != address(0)) {
                tokenIdToWorkWith++;
            }

            token.mint(sender, tokenIdToWorkWith);
            assetAddresses[i] = address(token);
            assetIds[i] = tokenIdToWorkWith;
            assetAmounts[i] = 1;
        }

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositERC1155InAccount(ERC1155Mock token, uint256 tokenId, uint256 amount, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetIds = new uint256[](1);
        assetAmounts = new uint256[](1);

        token.mint(sender, tokenId, amount);
        assetAddresses[0] = address(token);
        assetIds[0] = tokenId;
        assetAmounts[0] = amount;

        vm.startPrank(sender);
        proxy.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function createCompareStruct() public view returns (Checks memory) {
        Checks memory checks;

        checks.isTrustedCreditorSet = proxy.isTrustedCreditorSet();
        checks.baseCurrency = proxy.baseCurrency();
        checks.owner = proxy.owner();
        checks.liquidator = proxy.liquidator();
        checks.registry = proxy.registry();
        checks.trustedCreditor = proxy.trustedCreditor();
        (checks.assetAddresses, checks.assetIds, checks.assetAmounts) = proxy.generateAssetData();

        return checks;
    }
}
