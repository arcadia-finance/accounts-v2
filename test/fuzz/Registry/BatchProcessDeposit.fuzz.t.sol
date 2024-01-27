/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";
import { AssetModule } from "../../../src/asset-modules/abstracts/AbstractAM.sol";

/**
 * @notice Fuzz tests for the function "batchProcessDeposit" of contract "Registry".
 */
contract BatchProcessDeposit_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_batchProcessDeposit_Paused(address sender) public {
        vm.warp(35 days);
        vm.prank(users.guardian);
        registryExtension.pause();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(sender);
        vm.expectRevert(FunctionIsPaused.selector);
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
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

        // When: guardian pauses registryExtension
        vm.prank(users.creatorAddress);
        registryExtension.changeGuardian(guardian);
        vm.warp(35 days);
        vm.prank(guardian);
        registryExtension.pause();

        // Then: batchProcessDeposit should reverted
        vm.prank(address(proxyAccount));
        vm.expectRevert(FunctionIsPaused.selector);
        registryExtension.batchProcessDeposit(creditor, assetAddresses, assetIds, assetAmounts);
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
        registryExtension.setRiskParameters(address(creditorUsd), 0, 15 minutes, 0);

        vm.prank(address(proxyAccount));
        vm.expectRevert(RegistryErrors.MaxRecursiveCallsReached.selector);
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_batchProcessDeposit_NonAccount(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != address(proxyAccount));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.OnlyAccount.selector);
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
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

        vm.startPrank(address(proxyAccount));
        vm.expectRevert(RegistryErrors.LengthMismatch.selector);
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
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

        vm.startPrank(address(proxyAccount));
        vm.expectRevert(RegistryErrors.AssetNotAllowed.selector);
        registryExtension.batchProcessDeposit(address(0), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_WithoutCreditor_AssetNotInReg(address asset) public {
        vm.assume(!registryExtension.inRegistry(asset));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(address(proxyAccount));
        vm.expectRevert(bytes(""));
        registryExtension.batchProcessDeposit(address(0), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_WithCreditor_ExposureNotSufficient(
        uint112 newMaxExposure,
        uint112 amount
    ) public {
        amount = uint112(bound(amount, 1, type(uint112).max));
        vm.assume(newMaxExposure <= amount);

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC20.token1), 0, newMaxExposure, 0, 0
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(address(proxyAccount));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_WithCreditor_AssetNotInReg(address asset) public {
        vm.assume(!registryExtension.inRegistry(asset));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(address(proxyAccount));
        vm.expectRevert(bytes(""));
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
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

        vm.prank(address(proxyAccount));
        vm.expectEmit();
        emit Deposit(address(proxyAccount));
        uint256[] memory assetTypes =
            registryExtension.batchProcessDeposit(address(0), assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);
        assertEq(assetTypes[1], 1);
        assertEq(assetTypes[2], 2);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint112 exposureERC20,,,) = erc20AssetModule.riskParams(address(0), assetKey);
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

        vm.prank(address(proxyAccount));
        vm.expectEmit();
        emit Deposit(address(proxyAccount));
        uint256[] memory assetTypes =
            registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);
        assertEq(assetTypes[1], 1);
        assertEq(assetTypes[2], 2);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint112 exposureERC20,,,) = erc20AssetModule.riskParams(address(0), assetKey);
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

        vm.prank(address(proxyAccount));
        vm.expectEmit();
        emit Deposit(address(proxyAccount));
        uint256[] memory assetTypes =
            registryExtension.batchProcessDeposit(address(0), assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);
        assertEq(assetTypes[1], 2);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint112 exposureERC20,,,) = erc20AssetModule.riskParams(address(0), assetKey);
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

        vm.prank(address(proxyAccount));
        vm.expectEmit();
        emit Deposit(address(proxyAccount));
        uint256[] memory assetTypes =
            registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint112 exposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), assetKey);
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

        vm.prank(address(proxyAccount));
        vm.expectEmit();
        emit Deposit(address(proxyAccount));
        uint256[] memory assetTypes =
            registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);
        assertEq(assetTypes[1], 0);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint112 exposureToken1,,,) = erc20AssetModule.riskParams(address(creditorUsd), assetKey);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        (uint112 exposureToken2,,,) = erc20AssetModule.riskParams(address(creditorUsd), assetKey);

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

        vm.startPrank(address(proxyAccount));
        vm.expectEmit();
        emit Deposit(address(proxyAccount));
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        (uint112 newExposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), assetKey);

        assertEq(newExposure, amountToken2);
    }
}
