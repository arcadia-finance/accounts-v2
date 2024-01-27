/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractPrimaryAM_Fuzz_Test } from "./_AbstractPrimaryAM.fuzz.t.sol";

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { OracleModuleMock } from "../../../utils/mocks/oracle-modules/OracleModuleMock.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "AbstractPrimaryAM".
 */
contract GetValue_AbstractPrimaryAM_Fuzz_Test is AbstractPrimaryAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryAM_Fuzz_Test.setUp();

        oracleModule = new OracleModuleMock(address(registryExtension));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValue_Overflow(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 decimals,
        uint256 amount,
        uint80 oracleId,
        uint256 rate
    ) public {
        // No Overflow OracleModule.
        rate = bound(rate, 2, type(uint256).max / 1e18);

        // Overflow in AssetModule (test-case).
        amount = bound(amount, type(uint256).max / rate + 1, type(uint256).max);

        // Add oracle to OracleModule.
        addMockedOracle(oracleId, rate, bytes16("A"), bytes16("USD"), true);

        // Add asset to AssetModule.
        uint80[] memory oraclesIds = new uint80[](1);
        oraclesIds[0] = oracleId;
        bool[] memory baseToQuoteAsset = new bool[](1);
        baseToQuoteAsset[0] = true;
        bytes32 oracleSequence = BitPackingLib.pack(baseToQuoteAsset, oraclesIds);
        decimals = bound(decimals, 0, 18);
        assetModule.setAssetInformation(asset, assetId, uint64(10 ** decimals), oracleSequence);

        // Use actual getValue() and not the hard-coded value ToDo: refactor
        assetModule.setUseRealUsdValue(true);

        vm.expectRevert(bytes(""));
        assetModule.getValue(creditor, asset, assetId, amount);
    }

    function testFuzz_Success_getValue(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 decimals,
        uint256 amount,
        uint80 oracleId,
        uint256 rate
    ) public {
        // No Overflow OracleModule.
        rate = bound(rate, 0, type(uint256).max / 1e18);

        // No Overflow in AssetModule.
        if (rate > 0) amount = bound(amount, 0, type(uint256).max / rate);

        // Add oracle to OracleModule.
        addMockedOracle(oracleId, rate, bytes16("A"), bytes16("USD"), true);

        // Add asset to AssetModule.
        uint80[] memory oraclesIds = new uint80[](1);
        oraclesIds[0] = oracleId;
        bool[] memory baseToQuoteAsset = new bool[](1);
        baseToQuoteAsset[0] = true;
        bytes32 oracleSequence = BitPackingLib.pack(baseToQuoteAsset, oraclesIds);
        decimals = bound(decimals, 0, 18);
        assetModule.setAssetInformation(asset, assetId, uint64(10 ** decimals), oracleSequence);

        // Use actual getValue() and not the hard-coded value ToDo: refactor
        assetModule.setUseRealUsdValue(true);

        uint256 expectedValueInUsd = rate * amount / 10 ** decimals;

        // When: getValue called
        (uint256 actualValueInUsd,,) = assetModule.getValue(creditor, asset, assetId, amount);

        // Then: actualValueInUsd should be equal to expectedValueInUsd
        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
