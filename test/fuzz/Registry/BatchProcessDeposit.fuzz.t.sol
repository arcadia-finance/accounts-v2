/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";
import { AssetModule } from "../../../src/asset-modules/AbstractAssetModule.sol";

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
        vm.expectRevert(Function_Is_Paused.selector);
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
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
        vm.expectRevert(RegistryErrors.Only_Account.selector);
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_lengthMismatch() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.stable2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 1000;
        assetAmounts[1] = 1000;

        vm.startPrank(address(proxyAccount));
        vm.expectRevert(RegistryErrors.Length_Mismatch.selector);
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_exposureNotSufficient(uint128 newMaxExposure, uint128 amount) public {
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
        vm.expectRevert(AssetModule.Exposure_Not_In_Limits.selector);
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_AssetNotInReg(address asset) public {
        vm.assume(!registryExtension.inRegistry(asset));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(address(proxyAccount));
        vm.expectRevert();
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_Paused(
        address creditor,
        uint128 amountToken1,
        uint128 amountToken2,
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
        vm.expectRevert(Function_Is_Paused.selector);
        registryExtension.batchProcessDeposit(creditor, assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_batchProcessDeposit_SingleAsset(uint128 amount) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        amount = uint128(bound(amount, 0, type(uint128).max - 1));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(address(proxyAccount));
        uint256[] memory assetTypes =
            registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint128 exposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), assetKey);
        assertEq(exposure, amount);
    }

    function testFuzz_Success_batchProcessDeposit_MultipleAssets(uint128 amountToken1, uint128 amountToken2) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        amountToken1 = uint128(bound(amountToken1, 0, type(uint128).max - 1));
        amountToken2 = uint128(bound(amountToken2, 0, type(uint128).max - 1));

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
        uint256[] memory assetTypes =
            registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);
        assertEq(assetTypes[1], 0);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint128 exposureToken1,,,) = erc20AssetModule.riskParams(address(creditorUsd), assetKey);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        (uint128 exposureToken2,,,) = erc20AssetModule.riskParams(address(creditorUsd), assetKey);

        assertEq(exposureToken1, amountToken1);
        assertEq(exposureToken2, amountToken2);
    }

    function testFuzz_Success_batchProcessDeposit_directCall(uint128 amountToken2) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        amountToken2 = uint128(bound(amountToken2, 0, type(uint128).max - 1));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        vm.startPrank(address(proxyAccount));
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        (uint128 newExposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), assetKey);

        assertEq(newExposure, amountToken2);
    }
}