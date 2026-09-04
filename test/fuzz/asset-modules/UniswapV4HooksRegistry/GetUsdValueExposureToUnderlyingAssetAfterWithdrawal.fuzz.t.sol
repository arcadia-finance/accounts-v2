/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { OracleModuleMock } from "../../../utils/mocks/oracle-modules/OracleModuleMock.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { PrimaryAMMock } from "../../../utils/mocks/asset-modules/PrimaryAMMock.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getUsdValueExposureToUnderlyingAssetAfterWithdrawal" of contract "UniswapV4HooksRegistry".
 */
// forge-lint: disable-next-item(mixed-case-variable,unsafe-typecast)
contract GetUsdValueExposureToUnderlyingAssetAfterWithdrawal_UniswapV4HooksRegistry_Fuzz_Test is
    UniswapV4HooksRegistry_Fuzz_Test
{
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-next-line(mixed-case-variable)
    OracleModuleMock internal oracleModule;
    PrimaryAMMock internal primaryAM;

    uint256 internal constant PRIMARY_AM_ORACLE_ID = 999;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();

        vm.startPrank(users.owner);
        primaryAM = new PrimaryAMMock(users.owner, address(registry), 0);
        oracleModule = new OracleModuleMock(users.owner, address(registry));
        registry.addAssetModule(address(primaryAM));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function addMockedOracle(uint256 oracleId, uint256 rate, bytes16 baseAsset, bytes16 quoteAsset, bool active)
        public
    {
        oracleModule.setOracle(oracleId, baseAsset, quoteAsset, active);
        registry.setOracleToOracleModule(oracleId, address(oracleModule));
        oracleModule.setRate(oracleId, rate);
    }

    // forge-lint: disable-next-item(mixed-case-function,unsafe-typecast)
    function setPrimaryAMOracle(address asset, uint256 assetId, uint64 assetUnit, uint256 usdValue) public {
        addMockedOracle(PRIMARY_AM_ORACLE_ID, usdValue, bytes16("A"), bytes16("USD"), true);
        uint80[] memory oracleIds = new uint80[](1);
        oracleIds[0] = uint80(PRIMARY_AM_ORACLE_ID);
        bool[] memory baseToQuoteAsset = new bool[](1);
        baseToQuoteAsset[0] = true;
        primaryAM.setAssetInformation(asset, assetId, assetUnit, BitPackingLib.pack(baseToQuoteAsset, oracleIds));
    }

    function testFuzz_Revert_getUsdValueExposureToUnderlyingAssetAfterWithdrawal_NonAssetModule(
        address unprivilegedAddress_,
        address underlyingAsset,
        uint96 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) public {
        vm.assume(!v4HooksRegistry.isAssetModule(unprivilegedAddress_));

        vm.prank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        v4HooksRegistry.getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
            address(creditorUsd),
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );
    }

    function testFuzz_Success_getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
        address upperAssetModule,
        address underlyingAsset,
        uint96 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset,
        uint64 assetUnit,
        uint256 usdValue
    ) public {
        vm.assume(deltaExposureAssetToUnderlyingAsset <= type(int112).max); // MaxExposure.
        vm.assume(deltaExposureAssetToUnderlyingAsset > type(int256).min); // Overflows on inversion.

        registry.setAssetModule(underlyingAsset, address(primaryAM));

        // And: The asset price does not overflow.
        assetUnit = uint64(bound(assetUnit, 1, type(uint64).max));
        usdValue = bound(usdValue, 0, type(uint256).max / 1e18);
        exposureAssetToUnderlyingAsset = bound(
            exposureAssetToUnderlyingAsset, 0, usdValue == 0 ? type(uint256).max : type(uint256).max / usdValue
        );
        setPrimaryAMOracle(underlyingAsset, underlyingAssetId, assetUnit, usdValue);

        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), underlyingAsset, underlyingAssetId, type(uint112).max, 100, 100
        );

        stdstore.target(address(v4HooksRegistry))
            .sig(registry.isAssetModule.selector)
            .with_key(address(upperAssetModule))
            .checked_write(true);

        // Prepare expected internal call.
        bytes memory data = abi.encodeCall(
            primaryAM.processIndirectWithdrawal,
            (
                address(creditorUsd),
                underlyingAsset,
                underlyingAssetId,
                exposureAssetToUnderlyingAsset,
                deltaExposureAssetToUnderlyingAsset
            )
        );

        vm.prank(upperAssetModule);
        vm.expectCall(address(primaryAM), data);
        uint256 usdExposureAssetToUnderlyingAsset = v4HooksRegistry.getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
            address(creditorUsd),
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );

        assertEq(usdExposureAssetToUnderlyingAsset, exposureAssetToUnderlyingAsset * usdValue / assetUnit);
    }
}
