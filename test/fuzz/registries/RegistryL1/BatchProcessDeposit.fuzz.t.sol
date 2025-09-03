/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { RegistryL1_Fuzz_Test } from "./_RegistryL1.fuzz.t.sol";

import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { GuardianErrors } from "../../../../src/libraries/Errors.sol";
import { RegistryL1 } from "../../../../src/registries/RegistryL1.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
/**
 * @notice Fuzz tests for the function "batchProcessDeposit" of contract "RegistryL1".
 */

contract BatchProcessDeposit_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_batchProcessDeposit_Paused(address sender) public {
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
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_Paused(
        address creditor,
        uint112 amountToken1,
        uint112 amountToken2,
        address guardian
    ) public {
        // Given: Assets
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = amountToken1;
        assetAmounts[1] = amountToken2;

        // When: guardian pauses registry_
        vm.prank(users.owner);
        registry_.changeGuardian(guardian);
        vm.warp(35 days);
        vm.prank(guardian);
        registry_.pause();

        // Then: batchProcessDeposit should reverted
        vm.prank(address(account));
        vm.expectRevert(GuardianErrors.FunctionIsPaused.selector);
        registry_.batchProcessDeposit(creditor, assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_batchProcessDeposit_MaxRecursionReached(uint112 amountToken1, uint112 amountToken2)
        public
    {
        amountToken1 = uint112(bound(amountToken1, 1, type(uint112).max - 1));
        amountToken2 = uint112(bound(amountToken2, 1, type(uint112).max - 1));
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = amountToken1;
        assetAmounts[1] = amountToken2;

        vm.prank(users.riskManager);
        registry_.setRiskParameters(address(creditorUsd), 0, 0);

        vm.prank(address(account));
        vm.expectRevert(RegistryErrors.MaxRecursiveCallsReached.selector);
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_batchProcessDeposit_NonAccount(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != address(account));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.OnlyAccount.selector);
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_LengthMismatch() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.stable2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1000;

        vm.startPrank(address(account));
        vm.expectRevert(RegistryErrors.LengthMismatch.selector);
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_WithoutCreditor_NonAllowedAsset() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC1155.sft1);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 2;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 1;
        assetAmounts[1] = 1;

        vm.startPrank(address(account));
        vm.expectRevert(RegistryErrors.AssetNotAllowed.selector);
        registry_.batchProcessDeposit(address(0), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_WithoutCreditor_AssetNotInReg(address asset) public {
        vm.assume(!registry_.inRegistry(asset));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(address(account));
        vm.expectRevert(abi.encodePacked("call to non-contract address ", vm.toString(address(0))));
        registry_.batchProcessDeposit(address(0), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_WithCreditor_ExposureNotSufficient(
        uint112 newMaxExposure,
        uint112 amount
    ) public {
        amount = uint112(bound(amount, 1, type(uint112).max));
        vm.assume(newMaxExposure <= amount);

        vm.prank(users.riskManager);
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC20.token1), 0, newMaxExposure, 0, 0
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(address(account));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_WithCreditor_AssetNotInReg(address asset) public {
        vm.assume(!registry_.inRegistry(asset));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(address(account));
        vm.expectRevert(abi.encodePacked("call to non-contract address ", vm.toString(address(0))));
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Success_batchProcessDeposit_WithoutCreditor_ZeroAmounts(uint8 erc721Id) public {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC721.nft1);
        assetAddresses[2] = address(mockERC1155.sft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = erc721Id;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);

        vm.prank(address(account));
        registry_.batchProcessDeposit(address(0), assetAddresses, assetIds, assetAmounts);

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

    function testFuzz_Success_batchProcessDeposit_WithCreditor_ZeroAmounts(uint8 erc721Id) public {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC721.nft1);
        assetAddresses[2] = address(mockERC1155.sft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = erc721Id;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);

        vm.prank(address(account));
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

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

    function testFuzz_Success_batchProcessDeposit_WithoutCreditor_MultipleAssets(
        uint112 amountERC20,
        uint112 amountERC1155
    ) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        amountERC20 = uint112(bound(amountERC20, 0, type(uint112).max - 1));
        amountERC1155 = uint112(bound(amountERC1155, 0, type(uint112).max - 1));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC1155.sft1);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 1;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = amountERC20;
        assetAmounts[1] = amountERC1155;

        vm.prank(address(account));
        registry_.batchProcessDeposit(address(0), assetAddresses, assetIds, assetAmounts);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint112 exposureERC20,,,) = erc20AM.riskParams(address(0), assetKey);
        assetKey = bytes32(abi.encodePacked(uint96(1), address(mockERC1155.sft1)));
        (uint112 exposureERC1155,,,) = floorERC1155AM.riskParams(address(0), assetKey);

        assertEq(exposureERC20, 0);
        assertEq(exposureERC1155, 0);
    }

    function testFuzz_Success_batchProcessDeposit_WithCreditor_SingleAsset(uint112 amount) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        amount = uint112(bound(amount, 0, type(uint112).max - 1));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(address(account));
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint112 exposure,,,) = erc20AM.riskParams(address(creditorUsd), assetKey);
        assertEq(exposure, amount);
    }

    function testFuzz_Success_batchProcessDeposit_WithCreditor_MultipleAssets(
        uint112 amountToken1,
        uint112 amountToken2
    ) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        amountToken1 = uint112(bound(amountToken1, 0, type(uint112).max - 1));
        amountToken2 = uint112(bound(amountToken2, 0, type(uint112).max - 1));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = amountToken1;
        assetAmounts[1] = amountToken2;

        vm.prank(address(account));
        registry_.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint112 exposureToken1,,,) = erc20AM.riskParams(address(creditorUsd), assetKey);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        (uint112 exposureToken2,,,) = erc20AM.riskParams(address(creditorUsd), assetKey);

        assertEq(exposureToken1, amountToken1);
        assertEq(exposureToken2, amountToken2);
    }

    function testFuzz_Success_batchProcessDeposit_directCall(uint112 amountToken2) public {
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

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        (uint112 newExposure,,,) = erc20AM.riskParams(address(creditorUsd), assetKey);

        assertEq(newExposure, amountToken2);
    }
}
