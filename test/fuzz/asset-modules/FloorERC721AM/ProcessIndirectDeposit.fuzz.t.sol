/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FloorERC721AM_Fuzz_Test, AssetModule } from "./_FloorERC721AM.fuzz.t.sol";

import { FloorERC721AM } from "../../../utils/mocks/asset-modules/FloorERC721AM.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "FloorERC721AM".
 */
contract ProcessIndirectDeposit_FloorERC721AM_Fuzz_Test is FloorERC721AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectDeposit_NonRegistry(address unprivilegedAddress_, uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721AM.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, type(uint112).max, 0, 0
        );

        vm.assume(unprivilegedAddress_ != address(registryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        floorERC721AM.processIndirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 0, 0);
        vm.stopPrank();
    }

    function testFuzz_Revert_processIndirectDeposit_WrongID(uint256 assetId) public {
        vm.assume(assetId > 1); //Not in range
        vm.prank(users.creatorAddress);
        floorERC721AM.addAsset(address(mockERC721.nft2), 0, 1, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(address(creditorUsd), address(mockERC721.nft2), 0, 1, 0, 0);

        vm.startPrank(address(registryExtension));
        vm.expectRevert(FloorERC721AM.AssetNotAllowed.selector);
        floorERC721AM.processIndirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 0, 0);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 0);
    }

    function testFuzz_Revert_processIndirectDeposit_OverExposure(uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721AM.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(address(creditorUsd), address(mockERC721.nft2), 0, 2, 0, 0);

        vm.startPrank(address(registryExtension));
        floorERC721AM.processIndirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1, 1);

        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        floorERC721AM.processIndirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1, 1);
        vm.stopPrank();
    }

    function testFuzz_Success_processIndirectDeposit_positiveDelta(
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset,
        uint112 maxExposure
    ) public {
        vm.assume(deltaExposureUpperAssetToAsset > 0);
        vm.assume(uint256(deltaExposureUpperAssetToAsset) < maxExposure);
        // To avoid overflow when calculating "usdExposureUpperAssetToAsset"
        vm.assume(exposureUpperAssetToAsset < type(uint112).max);

        vm.prank(users.creatorAddress);
        floorERC721AM.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, maxExposure, 0, 0
        );

        (uint256 actualValueInUsd,,) = floorERC721AM.getValue(address(creditorUsd), address(mockERC721.nft2), 0, 1);

        vm.assume(actualValueInUsd * exposureUpperAssetToAsset < type(uint256).max);

        vm.prank(address(registryExtension));
        (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) = floorERC721AM.processIndirectDeposit(
            address(creditorUsd),
            address(mockERC721.nft2),
            assetId,
            exposureUpperAssetToAsset,
            deltaExposureUpperAssetToAsset
        );

        uint256 expectedUsdValueExposureUpperAssetToAsset = actualValueInUsd * exposureUpperAssetToAsset;
        assertEq(recursiveCalls, 1);
        assertEq(usdExposureUpperAssetToAsset, expectedUsdValueExposureUpperAssetToAsset);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, uint256(deltaExposureUpperAssetToAsset));
    }

    function testFuzz_Success_processIndirectDeposit_negativeDelta_NoUnderflow(
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        vm.assume(assetId != 1);
        vm.assume(assetId != 2);
        vm.assume(assetId != 3);
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, 1, 3);

        // To avoid overflow when calculating "usdExposureUpperAssetToAsset"
        exposureUpperAssetToAsset = bound(exposureUpperAssetToAsset, 0, type(uint112).max);

        vm.prank(users.creatorAddress);
        floorERC721AM.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(address(creditorUsd), address(mockERC721.nft2), 0, 4, 0, 0);

        vm.startPrank(address(registryExtension));
        floorERC721AM.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 1, 1);
        floorERC721AM.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 2, 1);
        floorERC721AM.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 3, 1);
        vm.stopPrank();

        (uint256 actualValueInUsd,,) = floorERC721AM.getValue(address(creditorUsd), address(mockERC721.nft2), 0, 1);

        vm.prank(address(registryExtension));
        (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) = floorERC721AM.processIndirectDeposit(
            address(creditorUsd),
            address(mockERC721.nft2),
            assetId,
            exposureUpperAssetToAsset,
            -int256(deltaExposureUpperAssetToAsset)
        );

        uint256 expectedUsdValueExposureUpperAssetToAsset = actualValueInUsd * exposureUpperAssetToAsset;
        assertEq(recursiveCalls, 1);
        assertEq(usdExposureUpperAssetToAsset, expectedUsdValueExposureUpperAssetToAsset);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 3 - deltaExposureUpperAssetToAsset);
    }

    function testFuzz_Success_processIndirectDeposit_negativeDelta_Underflow(
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        vm.assume(assetId != 1);
        vm.assume(assetId != 2);
        vm.assume(assetId != 3);
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, 4, type(uint96).max);

        // To avoid overflow when calculating "usdExposureUpperAssetToAsset"
        exposureUpperAssetToAsset = bound(exposureUpperAssetToAsset, 0, type(uint112).max);

        vm.prank(users.creatorAddress);
        floorERC721AM.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(address(creditorUsd), address(mockERC721.nft2), 0, 4, 0, 0);

        vm.startPrank(address(registryExtension));
        floorERC721AM.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 1, 1);
        floorERC721AM.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 2, 1);
        floorERC721AM.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 3, 1);
        vm.stopPrank();

        (uint256 actualValueInUsd,,) = floorERC721AM.getValue(address(creditorUsd), address(mockERC721.nft2), 0, 1);

        vm.prank(address(registryExtension));
        (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) = floorERC721AM.processIndirectDeposit(
            address(creditorUsd),
            address(mockERC721.nft2),
            assetId,
            exposureUpperAssetToAsset,
            -int256(deltaExposureUpperAssetToAsset)
        );

        uint256 expectedUsdValueExposureUpperAssetToAsset = actualValueInUsd * exposureUpperAssetToAsset;
        assertEq(recursiveCalls, 1);
        assertEq(usdExposureUpperAssetToAsset, expectedUsdValueExposureUpperAssetToAsset);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 0);
    }
}
