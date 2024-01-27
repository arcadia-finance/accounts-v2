/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

import { AccountV2 } from "../../../utils/mocks/accounts/AccountV2.sol";
import { AccountVariableVersion } from "../../../utils/mocks/accounts/AccountVariableVersion.sol";
import { Constants } from "../../../utils/Constants.sol";
import { RegistryExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "upgradeAccount" of contract "AccountV1".
 */
contract UpgradeAccount_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct Checks {
        address numeraire;
        address owner;
        address liquidator;
        address registry;
        address creditor;
        address[] assetAddresses;
        uint256[] assetIds;
        uint256[] assetAmounts;
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function createCompareStruct() public view returns (Checks memory) {
        Checks memory checks;

        checks.numeraire = proxyAccount.numeraire();
        checks.owner = proxyAccount.owner();
        checks.liquidator = proxyAccount.liquidator();
        checks.registry = proxyAccount.registry();
        checks.creditor = proxyAccount.creditor();
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
        factory.setNewAccountInfo(address(registryExtension), address(accountV2Logic), Constants.upgradeRoot1To2, "");
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_upgradeAccount_NonFactory(
        address newImplementation,
        address newRegistry,
        uint256 newVersion,
        address nonFactory,
        bytes calldata data
    ) public {
        vm.assume(nonFactory != address(factory));

        // Should revert if not called by the Factory.
        vm.startPrank(nonFactory);
        vm.expectRevert(AccountErrors.OnlyFactory.selector);
        proxyAccount.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_upgradeAccount_Reentered(
        address newImplementation,
        address newRegistry,
        uint256 newVersion,
        bytes calldata data
    ) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(address(factory));
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountExtension.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_upgradeAccount_NotDuringAuction(
        address newImplementation,
        address newRegistry,
        uint256 newVersion,
        bytes calldata data
    ) public {
        // Set "inAuction" to true.
        accountExtension.setInAuction();

        // Should revert if Account is being auctioned.
        vm.startPrank(address(factory));
        vm.expectRevert(AccountErrors.AccountInAuction.selector);
        accountExtension.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_upgradeAccount_InvalidAccountVersion(
        address newImplementation,
        uint256 newVersion,
        bytes calldata data
    ) public {
        // Given: Creditor is set.
        vm.prank(users.accountOwner);
        proxyAccount.openMarginAccount(address(creditorStable1));
        // Check in creditor if new version is allowed should fail.
        creditorStable1.setCallResult(false);

        vm.startPrank(address(factory));
        vm.expectRevert(AccountErrors.InvalidAccountVersion.selector);
        proxyAccount.upgradeAccount(newImplementation, address(registryExtension), newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_upgradeAccount_InvalidRegistry(address newImplementation, bytes calldata data)
        public
        notTestContracts(newImplementation)
    {
        vm.assume(newImplementation > address(10));
        vm.assume(newImplementation != address(proxyAccount));

        // Given: Creditor is set.
        vm.prank(users.accountOwner);
        proxyAccount.openMarginAccount(address(creditorStable1));

        uint256 accountVersion = factory.latestAccountVersion() + 1;
        AccountVariableVersion accountVarVersion = new AccountVariableVersion(accountVersion, address(factory));
        bytes memory code = address(accountVarVersion).code;
        vm.etch(newImplementation, code);
        AccountVariableVersion(newImplementation).setAccountVersion(accountVersion);
        AccountVariableVersion(newImplementation).setFactory(address(factory));

        vm.startPrank(users.creatorAddress);
        RegistryExtension registry2 = new RegistryExtension(address(factory), address(sequencerUptimeOracle));
        vm.assume(newImplementation != address(registry2));
        factory.setNewAccountInfo(address(registry2), newImplementation, Constants.upgradeRoot1To2, data);
        vm.stopPrank();

        vm.startPrank(address(factory));
        vm.expectRevert(AccountErrors.InvalidRegistry.selector);
        proxyAccount.upgradeAccount(newImplementation, address(registry2), uint16(accountVersion), data);
        vm.stopPrank();
    }

    function testFuzz_Success_upgradeAccountVersion(
        uint112 erc20Amount,
        uint8 erc721Id,
        uint112 erc1155Amount,
        uint256 debt,
        uint32 time
    ) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        erc20Amount = uint112(bound(erc20Amount, 0, type(uint112).max - 1));
        erc1155Amount = uint112(bound(erc1155Amount, 0, type(uint112).max - 1));

        // And: an account in a random state (with assets, a creditor and debt).
        vm.prank(users.accountOwner);
        proxyAccount.openMarginAccount(address(creditorStable1)); // Mocked Creditor, approves all account-versions by default.

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
        creditorStable1.setOpenPosition(address(proxyAccount), debt);

        Checks memory checkBefore = createCompareStruct();

        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        vm.warp(time);

        // When: "users.accountOwner" Upgrade the account to AccountV2Logic.
        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit AccountUpgraded(address(proxyAccount), 2);
        factory.upgradeAccountVersion(address(proxyAccount), factory.latestAccountVersion(), proofs);
        vm.stopPrank();

        // Then: Hook on new logic contract was called.
        assertEq(AccountV2(address(proxyAccount)).storageV2(), 5);

        // And: Proxy formwards calls to new logic contract.
        assertEq(AccountV2(address(proxyAccount)).returnFive(), 5);

        // And: The storage slots of all persisted data on the proxy contract are not overwritten.
        Checks memory checkAfter = createCompareStruct();
        assertEq(keccak256(abi.encode(checkAfter)), keccak256(abi.encode(checkBefore)));

        // And: The Account version is updated.
        assertEq(proxyAccount.ACCOUNT_VERSION(), factory.latestAccountVersion());

        // And: lastActionTimestamp is updated.
        assertEq(proxyAccount.lastActionTimestamp(), time);
    }
}
