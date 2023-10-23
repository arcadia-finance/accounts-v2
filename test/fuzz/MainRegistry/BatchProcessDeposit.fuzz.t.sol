/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "batchProcessDeposit" of contract "MainRegistry".
 */
contract BatchProcessDeposit_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_batchProcessDeposit_Paused(address sender) public {
        vm.warp(35 days);
        vm.prank(users.guardian);
        mainRegistryExtension.pause();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(sender);
        vm.expectRevert(FunctionIsPaused.selector);
        mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
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
        vm.expectRevert("MR: Only Accounts.");
        mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
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
        vm.expectRevert("MR_BPD: LENGTH_MISMATCH");
        mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_exposureNotSufficient(uint128 newMaxExposure, uint128 amount) public {
        vm.assume(newMaxExposure < amount);

        vm.prank(users.creatorAddress);
        erc20PricingModule.setMaxExposureOfAsset(address(mockERC20.token1), 0, newMaxExposure);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.startPrank(address(proxyAccount));
        vm.expectRevert("APPM_PDD: Exposure not in limits");
        mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_AssetNotInMainreg(address asset) public {
        vm.assume(!mainRegistryExtension.inMainRegistry(asset));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(address(proxyAccount));
        vm.expectRevert();
        mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testFuzz_Revert_batchProcessDeposit_Paused(uint128 amountToken1, uint128 amountToken2, address guardian)
        public
    {
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

        // When: guardian pauses mainRegistryExtension
        vm.prank(users.creatorAddress);
        mainRegistryExtension.changeGuardian(guardian);
        vm.warp(35 days);
        vm.prank(guardian);
        mainRegistryExtension.pause();

        // Then: batchProcessDeposit should reverted
        vm.prank(address(proxyAccount));
        vm.expectRevert(FunctionIsPaused.selector);
        mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_batchProcessDeposit_delegateCall(uint128 amountToken2) public {
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
                "batchProcessDeposit(address[] calldata,uint256[] calldata,uint256[] calldata)",
                assetAddresses,
                assetIds,
                assetAmounts
            )
        );
        vm.stopPrank();

        success; //avoid warning
    }

    function testFuzz_Success_batchProcessDeposit_SingleAsset(uint128 amount) public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(address(proxyAccount));
        uint256[] memory assetTypes = mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (, uint128 exposure) = erc20PricingModule.exposure(assetKey);
        assertEq(exposure, amount);
    }

    function testFuzz_Success_batchProcessDeposit_MultipleAssets(uint128 amountToken1, uint128 amountToken2) public {
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
        uint256[] memory assetTypes = mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);

        assertEq(assetTypes[0], 0);
        assertEq(assetTypes[1], 0);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (, uint256 exposureToken1) = erc20PricingModule.exposure(assetKey);
        assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        (, uint256 exposureToken2) = erc20PricingModule.exposure(assetKey);

        assertEq(exposureToken1, amountToken1);
        assertEq(exposureToken2, amountToken2);
    }

    function testFuzz_Success_batchProcessDeposit_directCall(uint128 amountToken2) public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        vm.startPrank(address(proxyAccount));
        mainRegistryExtension.batchProcessDeposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        (, uint128 newExposure) = erc20PricingModule.exposure(assetKey);

        assertEq(newExposure, amountToken2);
    }
}
