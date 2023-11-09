/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPrimaryPricingModule_Fuzz_Test } from "./_AbstractPrimaryPricingModule.fuzz.t.sol";

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { OracleModuleMock } from "../../../utils/mocks/OracleModuleMock.sol";

/**
 * @notice Fuzz tests for the function "checkOracleSequence" of contract "AbstractPrimaryPricingModule".
 */
contract CheckOracleSequence_AbstractPrimaryPricingModule_Fuzz_Test is AbstractPrimaryPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryPricingModule_Fuzz_Test.setUp();

        oracleModule = new OracleModuleMock(address(mainRegistryExtension));
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getOracleSequence(uint256 length, bool[3] memory directions, uint80[3] memory oracles)
        public
        pure
        returns (bytes32 oracleSequence)
    {
        bool[] memory directions_ = new bool[](length);
        uint80[] memory oracles_ = new uint80[](length);
        for (uint256 i; i < length; ++i) {
            directions_[i] = directions[i];
            oracles_[i] = oracles[i];

            // Oracles must be unique.
            for (uint256 j; j < i; ++j) {
                vm.assume(oracles_[i] != oracles_[j]);
            }
        }

        oracleSequence = BitPackingLib.pack(directions_, oracles_);
    }

    function addOracles(uint256 length, bool[3] memory directions, uint80[3] memory oracles) public {
        bytes16 baseAsset;
        bytes16 quoteAsset;
        if (length == 1) {
            (baseAsset, quoteAsset) = directions[0] ? (bytes16("A"), bytes16("USD")) : (bytes16("USD"), bytes16("A"));
            addMockedOracle(oracles[0], 0, baseAsset, quoteAsset, true);
        } else {
            (baseAsset, quoteAsset) = directions[0] ? (bytes16("A"), bytes16("B")) : (bytes16("B"), bytes16("A"));
            addMockedOracle(oracles[0], 0, baseAsset, quoteAsset, true);
            if (length == 2) {
                (baseAsset, quoteAsset) =
                    directions[1] ? (bytes16("B"), bytes16("USD")) : (bytes16("USD"), bytes16("B"));
                addMockedOracle(oracles[1], 0, baseAsset, quoteAsset, true);
            } else {
                (baseAsset, quoteAsset) = directions[1] ? (bytes16("B"), bytes16("C")) : (bytes16("C"), bytes16("B"));
                addMockedOracle(oracles[1], 0, baseAsset, quoteAsset, true);
                (baseAsset, quoteAsset) =
                    directions[2] ? (bytes16("C"), bytes16("USD")) : (bytes16("USD"), bytes16("C"));
                addMockedOracle(oracles[2], 0, baseAsset, quoteAsset, true);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_setOracles_NonOwner(
        address unprivilegedAddress_,
        address asset,
        uint256 assetId,
        bytes32 oracleSequenceNew
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.prank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        pricingModule.setOracles(asset, assetId, oracleSequenceNew);
    }

    function testFuzz_Revert_setOracles_OldOraclesActive(
        address asset,
        uint256 assetId,
        uint256 lengthOld,
        bool[3] memory directionsOld,
        uint80[3] memory oraclesOld,
        bytes32 oracleSequenceNew
    ) public {
        // Add the old oracles and set the oracle sequence for the asset.
        lengthOld = bound(lengthOld, 1, 3);
        addOracles(lengthOld, directionsOld, oraclesOld);
        bytes32 oracleSequenceOld = getOracleSequence(lengthOld, directionsOld, oraclesOld);
        pricingModule.setAssetInformation(asset, assetId, 0, oracleSequenceOld);

        vm.prank(users.creatorAddress);
        vm.expectRevert("APPM_SO: Oracle still active");
        pricingModule.setOracles(asset, assetId, oracleSequenceNew);
    }

    function testFuzz_Revert_setOracles_UnknownOracle(
        address asset,
        uint96 assetId,
        uint256 lengthOld,
        bool[3] memory directionsOld,
        uint80[3] memory oraclesOld,
        bool directionNew,
        uint80 oracleNew
    ) public {
        // Add the old oracles and set the oracle sequence for the asset.
        lengthOld = bound(lengthOld, 1, 3);
        addOracles(lengthOld, directionsOld, oraclesOld);
        bytes32 oracleSequenceOld = getOracleSequence(lengthOld, directionsOld, oraclesOld);
        pricingModule.setAssetInformation(asset, assetId, 0, oracleSequenceOld);

        // New oracle must be different from old oracles (-> unknown).
        vm.assume(!oracleModule.isActive(oracleNew));

        // And one of the old oracles is not active anymore.
        vm.assume(oraclesOld[0] != oracleNew);
        oracleModule.setIsActive(oraclesOld[0], false);

        uint80[] memory oraclesIds = new uint80[](1);
        oraclesIds[0] = oracleNew;
        bool[] memory directions = new bool[](1);
        directions[0] = directionNew;
        bytes32 oracleSequenceNew = BitPackingLib.pack(directions, oraclesIds);

        vm.prank(users.creatorAddress);
        vm.expectRevert(bytes(""));
        pricingModule.setOracles(asset, assetId, oracleSequenceNew);
    }

    function testFuzz_Revert_setOracles_BadSequence(
        address asset,
        uint96 assetId,
        uint256 lengthOld,
        bool[3] memory directionsOld,
        uint80[3] memory oraclesOld,
        bool directionNew,
        uint80 oracleNew
    ) public {
        // Add the old oracles and set the oracle sequence for the asset.
        lengthOld = bound(lengthOld, 1, 3);
        addOracles(lengthOld, directionsOld, oraclesOld);
        bytes32 oracleSequenceOld = getOracleSequence(lengthOld, directionsOld, oraclesOld);
        pricingModule.setAssetInformation(asset, assetId, 0, oracleSequenceOld);

        // And one of the old oracles is not active anymore.
        vm.assume(oraclesOld[0] != oracleNew);
        oracleModule.setIsActive(oraclesOld[0], false);

        // And new oracles have a bad sequence.
        (bytes16 baseAsset, bytes16 quoteAsset) =
            directionNew ? (bytes16("A"), bytes16("NON_USD")) : (bytes16("NON_USD"), bytes16("A"));
        addMockedOracle(oracleNew, 0, baseAsset, quoteAsset, false);
        uint80[] memory oraclesIds = new uint80[](1);
        oraclesIds[0] = oracleNew;
        bool[] memory directions = new bool[](1);
        directions[0] = directionNew;
        bytes32 oracleSequenceNew = BitPackingLib.pack(directions, oraclesIds);

        vm.prank(users.creatorAddress);
        vm.expectRevert("APPM_SO: Bad sequence");
        pricingModule.setOracles(asset, assetId, oracleSequenceNew);
    }

    function testFuzz_Success_setOracles(
        address asset,
        uint96 assetId,
        uint256 lengthOld,
        bool[3] memory directionsOld,
        uint80[3] memory oraclesOld,
        uint256 lengthNew,
        bool[3] memory directionsNew,
        uint80[3] memory oraclesNew
    ) public {
        // Add the old oracles and set the oracle sequence for the asset.
        lengthOld = bound(lengthOld, 1, 3);
        addOracles(lengthOld, directionsOld, oraclesOld);
        bytes32 oracleSequenceOld = getOracleSequence(lengthOld, directionsOld, oraclesOld);
        pricingModule.setAssetInformation(asset, assetId, 0, oracleSequenceOld);

        // And one of the old oracles is not active anymore.
        lengthNew = bound(lengthNew, 1, 3);
        for (uint256 i; i < lengthNew; ++i) {
            vm.assume(oraclesOld[0] != oraclesNew[i]);
        }
        oracleModule.setIsActive(oraclesOld[0], false);

        // Add the new oracles.
        addOracles(lengthNew, directionsNew, oraclesNew);
        bytes32 oracleSequenceNew = getOracleSequence(lengthNew, directionsNew, oraclesNew);

        vm.prank(users.creatorAddress);
        pricingModule.setOracles(asset, assetId, oracleSequenceNew);

        bytes32 assetKey = bytes32(abi.encodePacked(assetId, asset));
        (, bytes32 oracleSequence) = pricingModule.assetToInformation2(assetKey);

        assertEq(oracleSequence, oracleSequenceNew);
    }
}
