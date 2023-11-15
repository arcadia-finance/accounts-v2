/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Registry_Fuzz_Test } from "./_Registry.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "batchProcessWithdrawal" of contract "Registry".
 */
contract BatchProcessWithdrawal_Registry_Fuzz_Test is Registry_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_batchProcessWithdrawal_Paused(address sender) public {
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
        registryExtension.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessWithdrawal_NonAccount(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != address(proxyAccount));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("MR: Only Accounts.");
        registryExtension.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
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

        vm.startPrank(address(proxyAccount));
        vm.expectRevert("MR_BPW: LENGTH_MISMATCH");
        registryExtension.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessWithdrawal_Paused(uint128 amountToken2, address guardian) public {
        // Given: "exposure" is strictly smaller as "maxExposure".
        amountToken2 = uint128(bound(amountToken2, 0, type(uint128).max - 1));

        // And: Assets are deposited
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        vm.prank(address(proxyAccount));
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        // When: Registry is paused
        vm.prank(users.creatorAddress);
        registryExtension.changeGuardian(guardian);
        vm.warp(35 days);
        vm.prank(guardian);
        registryExtension.pause();

        // Then: Withdrawal is reverted due to paused Registry
        vm.startPrank(address(proxyAccount));
        vm.expectRevert(FunctionIsPaused.selector);
        registryExtension.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessWithdrawal_AssetNotInMainreg(
        uint128 amountDeposited,
        uint128 amountWithdrawn,
        address asset
    ) public {
        vm.assume(!registryExtension.inRegistry(asset));
        vm.assume(amountDeposited >= amountWithdrawn);

        stdstore.target(address(registryExtension)).sig(registryExtension.inRegistry.selector).with_key(address(asset))
            .checked_write(true);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountDeposited;

        stdstore.target(address(registryExtension)).sig(registryExtension.inRegistry.selector).with_key(asset)
            .checked_write(false);

        assetAmounts[0] = amountWithdrawn;

        vm.prank(address(proxyAccount));
        vm.expectRevert();
        registryExtension.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_batchProcessWithdrawal_delegateCall(uint128 amountToken2) public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        vm.startPrank(address(proxyAccount));
        vm.expectRevert("MR: No delegate.");
        (bool success,) = address(registryExtension).delegatecall(
            abi.encodeWithSignature(
                "batchProcessWithdrawal(address[] calldata,uint256[] calldata,uint256[] calldata)",
                assetAddresses,
                assetIds,
                assetAmounts
            )
        );
        vm.stopPrank();

        success; //avoid warning
    }

    function testFuzz_Success_batchProcessWithdrawal(uint128 amountDeposited, uint128 amountWithdrawn) public {
        // Given: "exposure" is strictly smaller as "maxExposure".
        amountDeposited = uint128(bound(amountDeposited, 0, type(uint128).max - 1));
        amountWithdrawn = uint128(bound(amountWithdrawn, 0, amountDeposited));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountDeposited;

        vm.prank(address(proxyAccount));
        registryExtension.batchProcessDeposit(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint128 exposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), assetKey);

        assertEq(exposure, amountDeposited);

        assetAmounts[0] = amountWithdrawn;

        vm.prank(address(proxyAccount));
        uint256[] memory assetTypes =
            registryExtension.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);

        (exposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), assetKey);

        assertEq(exposure, amountDeposited - amountWithdrawn);
    }

    function testFuzz_Success_batchProcessWithdrawal_directCall(uint128 amountToken2) public {
        // Given: "exposure" is strictly smaller as "maxExposure".
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

        vm.startPrank(address(proxyAccount));
        registryExtension.batchProcessWithdrawal(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        (uint128 endExposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), assetKey);

        assertEq(endExposure, 0);
    }
}
