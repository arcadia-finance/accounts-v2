/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountSpot_Fuzz_Test } from "./_AccountSpot.fuzz.t.sol";
import { AccountSpotExtension } from "../../../utils/extensions/AccountSpotExtension.sol";
import { AccountV1 } from "../../../../src/accounts/AccountV1.sol";
import { AccountVariableVersion } from "../../../utils/mocks/accounts/AccountVariableVersion.sol";
import { Constants } from "../../../utils/Constants.sol";
import { Factory } from "../../../../src/Factory.sol";
import { RegistryL2Extension } from "../../../utils/extensions/RegistryL2Extension.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "upgradeHook" of contract "AccountSpot".
 */
contract UpgradeHook_AccountSpot_Fuzz_Test is AccountSpot_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountV1 internal accountV1;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountSpot_Fuzz_Test) {
        AccountSpot_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_upgradeHook_NonSelf(
        address caller,
        address oldImplementation,
        address oldRegistry,
        uint256 oldVersion,
        bytes calldata data
    ) public {
        // Given: Caller is not the account.
        vm.assume(caller != address(accountSpot));

        // When: Caller calls upgradeHook.
        // Then: It should revert.
        vm.prank(caller);
        vm.expectRevert(AccountErrors.OnlySelf.selector);
        accountSpot.upgradeHook(oldImplementation, oldRegistry, oldVersion, data);
    }

    function testFuzz_Revert_upgradeHook_InvalidRegistry(
        address oldImplementation,
        address oldRegistry,
        uint256 oldVersion,
        bytes calldata data
    ) public {
        // Given: Registry is zero address.
        stdstore.target(address(accountSpotLogic)).sig(accountSpotLogic.registry.selector).checked_write(address(0));

        // When: Account calls upgradeHook.
        // Then: It should revert.
        vm.prank(address(accountSpotLogic));
        vm.expectRevert(AccountErrors.InvalidRegistry.selector);
        accountSpotLogic.upgradeHook(oldImplementation, oldRegistry, oldVersion, data);
    }

    function testFuzz_Revert_upgradeHook_CreditorSet(
        address creditor,
        address oldImplementation,
        address oldRegistry,
        uint256 oldVersion,
        bytes calldata data
    ) public {
        // Given: Creditor is set.
        vm.assume(creditor != address(0));
        stdstore.target(address(accountSpotLogic)).sig(accountSpotLogic.creditor.selector).checked_write(creditor);

        // And: Registry is not zero address.
        stdstore.target(address(accountSpotLogic)).sig(accountSpotLogic.registry.selector).checked_write(
            address(registry)
        );

        // When: Account calls upgradeHook.
        // Then: It should revert.
        vm.prank(address(accountSpotLogic));
        vm.expectRevert(AccountErrors.InvalidUpgrade.selector);
        accountSpotLogic.upgradeHook(oldImplementation, oldRegistry, oldVersion, data);
    }

    function testFuzz_Revert_upgradeHook_AuctionOngoing(
        address oldImplementation,
        address oldRegistry,
        uint256 oldVersion,
        bytes calldata data
    ) public {
        // Given: Auction is ongoing.
        stdstore.target(address(accountSpotLogic)).sig(accountSpotLogic.inAuction.selector).checked_write(true);

        // And: Registry is not zero address.
        stdstore.target(address(accountSpotLogic)).sig(accountSpotLogic.registry.selector).checked_write(
            address(registry)
        );

        // When: Account calls upgradeHook.
        // Then: It should revert.
        vm.prank(address(accountSpotLogic));
        vm.expectRevert(AccountErrors.InvalidUpgrade.selector);
        accountSpotLogic.upgradeHook(oldImplementation, oldRegistry, oldVersion, data);
    }

    function testFuzz_Success_upgradeHook(uint112 erc20Amount, uint8 erc721Id, uint112 erc1155Amount) public {
        // Given: Initial V1 Account.
        vm.prank(users.accountOwner);
        address payable proxyAddress = payable(factory.createAccount(1001, 1, address(0)));
        accountV1 = AccountV1(proxyAddress);

        // And: Accounts can be upgraded from V1 to V2.
        stdstore.target(address(factory)).sig(factory.versionRoot.selector).checked_write(Constants.upgradeRoot1To2);

        // And: "exposure" is strictly smaller than "maxExposure".
        erc20Amount = uint112(bound(erc20Amount, 0, type(uint112).max - 1));
        erc1155Amount = uint112(bound(erc1155Amount, 0, type(uint112).max - 1));

        // And: Account has assets.
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
        mockERC20.token1.approve(address(accountV1), type(uint256).max);
        mockERC721.nft1.setApprovalForAll(address(accountV1), true);
        mockERC1155.sft1.setApprovalForAll(address(accountV1), true);
        vm.stopPrank();

        vm.prank(users.accountOwner);
        accountV1.deposit(assetAddresses, assetIds, assetAmounts);

        // When: "users.accountOwner" Upgrade the account to SpotAccount.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;
        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit Factory.AccountUpgraded(address(accountV1), 2);
        factory.upgradeAccountVersion(address(accountV1), 2, proofs);
        vm.stopPrank();

        accountSpot = AccountSpotExtension(proxyAddress);

        // And: The Account version is updated.
        assertEq(accountSpot.ACCOUNT_VERSION(), 2);

        // And: registry is valid
        assertEq(accountSpot.registry(), address(registry));

        // And: Deprecated storage variables are zeroed.
        assertEq(accountSpot.liquidator(), address(0));
        assertEq(accountSpot.minimumMargin(), 0);
        assertEq(accountSpot.numeraire(), address(0));
        assertEq(accountSpot.erc20Balances(address(mockERC20.token1)), 0);
        assertEq(accountSpot.erc1155Balances(address(mockERC1155.sft1), 1), 0);
        (assetAddresses, assetIds, assetAmounts) = accountSpot.generateAssetData();
        assertEq(assetAddresses.length, 0);
        assertEq(assetIds.length, 0);
        assertEq(assetAmounts.length, 0);
    }
}
