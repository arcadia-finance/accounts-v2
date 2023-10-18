/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { AccountV2 } from "../../../utils/mocks/AccountV2.sol";

/**
 * @notice Fuzz tests for the "upgradeAccount" of contract "AccountV1".
 */
contract UpgradeAccount_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

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

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function createCompareStruct() public view returns (Checks memory) {
        Checks memory checks;

        checks.isTrustedCreditorSet = proxyAccount.isTrustedCreditorSet();
        checks.baseCurrency = proxyAccount.baseCurrency();
        checks.owner = proxyAccount.owner();
        checks.liquidator = proxyAccount.liquidator();
        checks.registry = proxyAccount.registry();
        checks.trustedCreditor = proxyAccount.trustedCreditor();
        (checks.assetAddresses, checks.assetIds, checks.assetAmounts) = proxyAccount.generateAssetData();

        return checks;
    }

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

        // Set a Mocked V2 Account Logic contract in the Factory.
        vm.prank(users.creatorAddress);
        factory.setNewAccountInfo(
            address(mainRegistryExtension), address(accountV2Logic), Constants.upgradeRoot1To2, ""
        );
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_upgradeAccount_Reentered(
        address newImplementation,
        address newRegistry,
        uint16 newVersion,
        bytes calldata data
    ) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(users.accountOwner);
        vm.expectRevert("A: REENTRANCY");
        accountExtension.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_upgradeAccount_NonFactory(
        address newImplementation,
        address newRegistry,
        uint16 newVersion,
        address nonFactory,
        bytes calldata data
    ) public {
        vm.assume(nonFactory != address(factory));

        // Should revert if not called by the Factory.
        vm.startPrank(nonFactory);
        vm.expectRevert("A: Only Factory");
        proxyAccount.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_upgradeAccount_InvalidAccountVersion(
        address newImplementation,
        address newRegistry,
        uint16 newVersion,
        bytes calldata data
    ) public {
        // Given: Trusted Creditor is set.
        vm.prank(users.accountOwner);
        proxyAccount.openTrustedMarginAccount(address(trustedCreditor));
        // Check in creditor if new version is allowed should fail.
        trustedCreditor.setCallResult(false);

        vm.startPrank(address(factory));
        vm.expectRevert("A_UA: Invalid Account version");
        proxyAccount.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Success_upgradeAccountVersion(
        uint128 erc20Amount,
        uint8 erc721Id,
        uint128 erc1155Amount,
        uint256 debt
    ) public {
        // Given: an account in a random state (with assets, a creditor and debt).
        vm.prank(users.accountOwner);
        proxyAccount.openTrustedMarginAccount(address(trustedCreditor)); // Mocked Trusted Creditor, approves all account-versions by default.

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

        mockERC20.token1.mint(users.accountOwner, erc20Amount);
        mockERC721.nft1.mint(users.accountOwner, erc721Id);
        mockERC1155.sft1.mint(users.accountOwner, 1, erc1155Amount);
        vm.startPrank(users.accountOwner);
        mockERC20.token1.approve(address(proxyAccount), type(uint256).max);
        mockERC721.nft1.setApprovalForAll(address(proxyAccount), true);
        mockERC1155.sft1.setApprovalForAll(address(proxyAccount), true);
        vm.stopPrank();

        vm.prank(users.accountOwner);
        proxyAccount.deposit(assetAddresses, assetIds, assetAmounts);

        // Mock initial debt.
        trustedCreditor.setOpenPosition(address(proxyAccount), debt);

        Checks memory checkBefore = createCompareStruct();

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        // When: "users.accountOwner" Upgrade the account to AccountV2Logic.
        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit AccountUpgraded(address(proxyAccount), 1, 2);
        factory.upgradeAccountVersion(address(proxyAccount), factory.latestAccountVersion(), proofs);
        vm.stopPrank();

        // Then: Hook on new logic contract was called.
        assertEq(AccountV2(address(proxyAccount)).storageV2(), 5);

        // And: Proxy formwards calls to new logic contract.
        assertEq(AccountV2(address(proxyAccount)).returnFive(), 5);

        // And: The storage slots of all persisted data on the proxy contract are not overwritten.
        Checks memory checkAfter = createCompareStruct();
        assertEq(keccak256(abi.encode(checkAfter)), keccak256(abi.encode(checkBefore)));

        // And: The Vault version is updated.
        assertEq(proxyAccount.ACCOUNT_VERSION(), factory.latestAccountVersion());
    }
}
