/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryL1_Fuzz_Test } from "./_RegistryL1.fuzz.t.sol";

import { GuardianErrors } from "../../../../src/libraries/Errors.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "batchProcessWithdrawal" of contract "RegistryL1".
 */
contract BatchProcessWithdrawal_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_batchProcessWithdrawal_Paused(address sender) public {
        vm.warp(35 days);
        vm.prank(users.guardian);
        registry_.pause();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(sender);
        vm.expectRevert(GuardianErrors.FunctionIsPaused.selector);
        registry_.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessWithdrawal_Paused(uint112 amountToken2, address guardian) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        amountToken2 = uint112(bound(amountToken2, 0, type(uint112).max - 1));

        // And: Assets are deposited
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        vm.prank(address(account));
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        // When: Registry is paused
        vm.prank(users.owner);
        registry_.changeGuardian(guardian);
        vm.warp(35 days);
        vm.prank(guardian);
        registry_.pause();

        // Then: Withdrawal is reverted due to paused Registry
        vm.startPrank(address(account));
        vm.expectRevert(GuardianErrors.FunctionIsPaused.selector);
        registry_.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessWithdrawal_NonAccount(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != address(account));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.OnlyAccount.selector);
        registry_.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessWithdrawal_lengthMismatch() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.stable2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1000;

        vm.startPrank(address(account));
        vm.expectRevert(RegistryErrors.LengthMismatch.selector);
        registry_.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessWithdrawal_WithoutCreditor_AssetNotInReg(
        uint112 amountDeposited,
        uint112 amountWithdrawn,
        address asset
    ) public {
        vm.assume(!registry_.inRegistry(asset));
        vm.assume(amountDeposited >= amountWithdrawn);

        stdstore.target(address(registry_)).sig(registry_.inRegistry.selector).with_key(address(asset)).checked_write(
            true
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountDeposited;

        stdstore.target(address(registry_)).sig(registry_.inRegistry.selector).with_key(asset).checked_write(false);

        assetAmounts[0] = amountWithdrawn;

        vm.prank(address(account));
        vm.expectRevert(RegistryErrors.UnknownAsset.selector);
        registry_.batchProcessWithdrawal(address(0), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_batchProcessWithdrawal_WithCreditor_AssetNotInReg(
        uint112 amountDeposited,
        uint112 amountWithdrawn,
        address asset
    ) public {
        vm.assume(!registry_.inRegistry(asset));
        amountWithdrawn = uint112(bound(amountWithdrawn, 1, type(uint112).max));
        vm.assume(amountDeposited >= amountWithdrawn);

        stdstore.target(address(registry_)).sig(registry_.inRegistry.selector).with_key(address(asset)).checked_write(
            true
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountDeposited;

        stdstore.target(address(registry_)).sig(registry_.inRegistry.selector).with_key(asset).checked_write(false);

        assetAmounts[0] = amountWithdrawn;

        vm.prank(address(account));
        vm.expectRevert(abi.encodePacked("call to non-contract address ", vm.toString(address(0))));
        registry_.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_batchProcessWithdrawal_WithoutCreditor_ZeroAmounts(
        uint112 erc20Amount,
        uint8 erc721Id,
        uint112 erc1155Amount
    ) public {
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

        vm.prank(address(account));
        registry_.batchProcessDeposit(address(0), assetAddresses, assetIds, assetAmounts);

        // When: zero amounts are withdrawn.
        assetAmounts = new uint256[](3);
        vm.prank(address(account));
        uint256[] memory assetTypes =
            registry_.batchProcessWithdrawal(address(0), assetAddresses, assetIds, assetAmounts);

        // Then: assetType 0 is returned for all assets.
        assertEq(assetTypes[0], 1);
        assertEq(assetTypes[1], 2);
        assertEq(assetTypes[2], 3);

        // And: exposures remain zero.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint112 exposureERC20,,,) = erc20AM.riskParams(address(0), assetKey);
        assertEq(exposureERC20, 0);

        assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft1)));
        (uint112 exposureERC721,,,) = floorERC721AM.riskParams(address(0), assetKey);
        assertEq(exposureERC721, 0);

        assetKey = bytes32(abi.encodePacked(uint96(1), address(mockERC1155.sft1)));
        (uint112 exposureERC1155,,,) = floorERC1155AM.riskParams(address(0), assetKey);
        assertEq(exposureERC1155, 0);
    }

    function testFuzz_Success_batchProcessWithdrawal_WithCreditor_ZeroAmounts(
        uint112 erc20Amount,
        uint8 erc721Id,
        uint112 erc1155Amount
    ) public {
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

        vm.prank(address(account));
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        // When: zero amounts are withdrawn.
        assetAmounts = new uint256[](3);
        vm.prank(address(account));
        uint256[] memory assetTypes =
            registry_.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        // Then: assetType are returned.
        assertEq(assetTypes[0], 1);
        assertEq(assetTypes[1], 2);
        assertEq(assetTypes[2], 3);

        // And: exposures are not updated.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint112 exposureERC20,,,) = erc20AM.riskParams(address(creditorUsd), assetKey);
        assertEq(exposureERC20, erc20Amount);

        assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft1)));
        (uint112 exposureERC721,,,) = floorERC721AM.riskParams(address(creditorUsd), assetKey);
        assertEq(exposureERC721, 1);

        assetKey = bytes32(abi.encodePacked(uint96(1), address(mockERC1155.sft1)));
        (uint112 exposureERC1155,,,) = floorERC1155AM.riskParams(address(creditorUsd), assetKey);
        assertEq(exposureERC1155, erc1155Amount);
    }

    function testFuzz_Success_batchProcessWithdrawal_WithoutCreditor(uint112 amountDeposited, uint112 amountWithdrawn)
        public
    {
        // Given: "exposure" is strictly smaller than "maxExposure".
        amountDeposited = uint112(bound(amountDeposited, 0, type(uint112).max - 1));
        amountWithdrawn = uint112(bound(amountWithdrawn, 0, amountDeposited));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountDeposited;

        vm.prank(address(account));
        registry_.batchProcessDeposit(address(0), assetAddresses, assetIds, assetAmounts);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint128 exposure,,,) = erc20AM.riskParams(address(0), assetKey);

        assertEq(exposure, 0);

        assetAmounts[0] = amountWithdrawn;

        vm.prank(address(account));
        uint256[] memory assetTypes =
            registry_.batchProcessWithdrawal(address(0), assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 1);

        (exposure,,,) = erc20AM.riskParams(address(0), assetKey);

        assertEq(exposure, 0);
    }

    function testFuzz_Success_batchProcessWithdrawal_WithCreditor(uint112 amountDeposited, uint112 amountWithdrawn)
        public
    {
        // Given: "exposure" is strictly smaller than "maxExposure".
        amountDeposited = uint112(bound(amountDeposited, 0, type(uint112).max - 1));
        amountWithdrawn = uint112(bound(amountWithdrawn, 0, amountDeposited));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountDeposited;

        vm.prank(address(account));
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint128 exposure,,,) = erc20AM.riskParams(address(creditorUsd), assetKey);

        assertEq(exposure, amountDeposited);

        assetAmounts[0] = amountWithdrawn;

        vm.prank(address(account));
        uint256[] memory assetTypes =
            registry_.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 1);

        (exposure,,,) = erc20AM.riskParams(address(creditorUsd), assetKey);

        assertEq(exposure, amountDeposited - amountWithdrawn);
    }

    function testFuzz_Success_batchProcessWithdrawal_directCall(uint112 amountToken2) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        amountToken2 = uint112(bound(amountToken2, 0, type(uint112).max - 1));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        vm.startPrank(address(account));
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        vm.startPrank(address(account));
        registry_.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        (uint128 endExposure,,,) = erc20AM.riskParams(address(creditorUsd), assetKey);

        assertEq(endExposure, 0);
    }
}
