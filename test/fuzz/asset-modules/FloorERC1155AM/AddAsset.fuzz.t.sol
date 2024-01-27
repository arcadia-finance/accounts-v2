/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FloorERC1155AM_Fuzz_Test } from "./_FloorERC1155AM.fuzz.t.sol";

import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { FloorERC1155AM } from "../../../utils/mocks/asset-modules/FloorERC1155AM.sol";
import { PrimaryAM } from "../../../../src/asset-modules/abstracts/AbstractPrimaryAM.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "FloorERC1155AM".
 */
contract AddAsset_FloorERC1155AM_Fuzz_Test is FloorERC1155AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.prank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 1, oraclesSft2ToUsd);
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(users.creatorAddress);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 1, oraclesSft2ToUsd);
        vm.expectRevert(FloorERC1155AM.AssetAlreadyInAM.selector);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 1, oraclesSft2ToUsd);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_InvalidId(uint256 id) public {
        id = bound(id, uint256(type(uint96).max) + 1, type(uint256).max);

        vm.prank(users.creatorAddress);
        vm.expectRevert(FloorERC1155AM.InvalidId.selector);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), id, oraclesSft2ToUsd);
    }

    function testFuzz_Revert_addAsset_BadOracleSequence() public {
        bool[] memory badDirection = new bool[](1);
        badDirection[0] = false;
        uint80[] memory oracleSft2ToUsdArr = new uint80[](1);
        oracleSft2ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.sft2ToUsd)));
        bytes32 badSequence = BitPackingLib.pack(badDirection, oracleSft2ToUsdArr);

        vm.prank(users.creatorAddress);
        vm.expectRevert(PrimaryAM.BadOracleSequence.selector);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 1, badSequence);
    }

    function testFuzz_Success_addAsset_FirstId() public {
        vm.prank(users.creatorAddress);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 1, oraclesSft2ToUsd);

        assertTrue(floorERC1155AM.inAssetModule(address(mockERC1155.sft2)));
        assertTrue(floorERC1155AM.isAllowed(address(mockERC1155.sft2), 1));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(1), address(mockERC1155.sft2)));
        (uint64 assetUnit, bytes32 oracles) = floorERC1155AM.assetToInformation(assetKey);
        assertEq(assetUnit, 1);
        assertEq(oracles, oraclesSft2ToUsd);

        assertTrue(registryExtension.inRegistry(address(mockERC1155.sft2)));
        address assetModule = registryExtension.assetToAssetModule(address(mockERC1155.sft2));
        assertEq(assetModule, address(floorERC1155AM));
    }

    function testFuzz_Success_addAsset_SecondId() public {
        vm.startPrank(users.creatorAddress);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 1, oraclesSft2ToUsd);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 2, oraclesSft2ToUsd);
        vm.stopPrank();

        assertTrue(floorERC1155AM.isAllowed(address(mockERC1155.sft2), 2));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(2), address(mockERC1155.sft2)));
        (uint64 assetUnit, bytes32 oracles) = floorERC1155AM.assetToInformation(assetKey);
        assertEq(assetUnit, 1);
        assertEq(oracles, oraclesSft2ToUsd);
    }
}
