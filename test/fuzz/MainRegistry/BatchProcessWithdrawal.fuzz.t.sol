/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the "batchProcessWithdrawal" of contract "MainRegistry".
 */
contract BatchProcessWithdrawal_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
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
        mainRegistryExtension.batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts);
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
        mainRegistryExtension.batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessWithdrawal_Paused(uint128 amountToken2, address guardian) public {
        // Given: Assets are deposited
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        vm.prank(address(proxyAccount));
        mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);

        // When: Main registry is paused
        vm.prank(users.creatorAddress);
        mainRegistryExtension.changeGuardian(guardian);
        vm.warp(35 days);
        vm.prank(guardian);
        mainRegistryExtension.pause();

        // Then: Withdrawal is reverted due to paused main registry
        vm.startPrank(address(proxyAccount));
        vm.expectRevert(FunctionIsPaused.selector);
        mainRegistryExtension.batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessWithdrawal_AssetNotInMainreg(
        uint128 amountDeposited,
        uint128 amountWithdrawn,
        address asset
    ) public {
        vm.assume(amountDeposited >= amountWithdrawn);

        stdstore.target(address(mainRegistryExtension)).sig(mainRegistryExtension.inMainRegistry.selector).with_key(
            address(asset)
        ).checked_write(true);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountDeposited;

        stdstore.target(address(mainRegistryExtension)).sig(mainRegistryExtension.inMainRegistry.selector).with_key(
            asset
        ).checked_write(false);

        assetAmounts[0] = amountWithdrawn;

        vm.prank(address(proxyAccount));
        vm.expectRevert();
        mainRegistryExtension.batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts);
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
        (bool success,) = address(mainRegistryExtension).delegatecall(
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
        vm.assume(amountDeposited >= amountWithdrawn);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountDeposited;

        vm.prank(address(proxyAccount));
        mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);

        (, uint256 exposure) = erc20PricingModule.exposure(address(mockERC20.token1));

        assertEq(exposure, amountDeposited);

        assetAmounts[0] = amountWithdrawn;

        vm.prank(address(proxyAccount));
        uint256[] memory assetTypes =
            mainRegistryExtension.batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);

        (, exposure) = erc20PricingModule.exposure(address(mockERC20.token1));

        assertEq(exposure, amountDeposited - amountWithdrawn);
    }

    function testFuzz_Success_batchProcessWithdrawal_directCall(uint128 amountToken2) public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        vm.startPrank(address(proxyAccount));
        mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        vm.startPrank(address(proxyAccount));
        mainRegistryExtension.batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        (, uint128 endExposure) = erc20PricingModule.exposure(address(mockERC20.token2));

        assertEq(endExposure, 0);
    }
}
