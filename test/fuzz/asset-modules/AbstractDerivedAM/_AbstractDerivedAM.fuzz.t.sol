/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { DerivedAMMock } from "../../../utils/mocks/asset-modules/DerivedAMMock.sol";
import { OracleModuleMock } from "../../../utils/mocks/oracle-modules/OracleModuleMock.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { PrimaryAMMock } from "../../../utils/mocks/asset-modules/PrimaryAMMock.sol";

/**
 * @notice Common logic needed by all "DerivedAM" fuzz tests.
 */
// forge-lint: disable-next-item(unsafe-typecast)
abstract contract AbstractDerivedAM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-start(pascal-case-struct)
    struct DerivedAMProtocolState {
        uint112 lastUsdExposureProtocol;
        uint112 maxUsdExposureProtocol;
    }

    struct DerivedAMAssetState {
        address creditor;
        address asset;
        uint256 assetId;
        uint112 exposureAssetLast;
        uint112 lastUsdExposureAsset;
        address underlyingAsset;
        uint256 underlyingAssetId;
        uint256 exposureAssetToUnderlyingAsset;
        uint112 lastExposureAssetToUnderlyingAsset;
    }
    // forge-lint: disable-end(pascal-case-struct)

    struct UnderlyingAssetModuleState {
        uint112 exposureAssetLast;
        uint64 assetUnit;
        uint256 rateInUsd;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-start(mixed-case-variable)
    DerivedAMMock internal derivedAM;
    OracleModuleMock internal oracleModule;
    PrimaryAMMock internal primaryAM;

    uint256 internal constant PRIMARY_AM_ORACLE_ID = 999;
    // forge-lint: disable-end(mixed-case-variable)

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.owner);

        derivedAM = new DerivedAMMock(users.owner, address(registry), 0);

        primaryAM = new PrimaryAMMock(users.owner, address(registry), 0);
        oracleModule = new OracleModuleMock(users.owner, address(registry));

        registry.addAssetModule(address(derivedAM));
        registry.addAssetModule(address(primaryAM));

        // We assume conversion rate and price of underlying asset both equal to 1.
        // Conversion rate and prices of underlying assets will be tested in specific asset modules.
        derivedAM.setUnderlyingAssetsAmount(1e18);

        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-next-item(mixed-case-function)
    function setDerivedAMProtocolState(DerivedAMProtocolState memory protocolState, address creditor) internal {
        derivedAM.setUsdExposureProtocol(
            creditor, protocolState.maxUsdExposureProtocol, protocolState.lastUsdExposureProtocol
        );
    }

    // forge-lint: disable-next-item(mixed-case-function)
    function setDerivedAMAssetState(DerivedAMAssetState memory assetState) internal {
        address[] memory underlyingAssets = new address[](1);
        underlyingAssets[0] = assetState.underlyingAsset;
        uint256[] memory underlyingAssetIds = new uint256[](1);
        underlyingAssetIds[0] = assetState.underlyingAssetId;
        derivedAM.addAsset(assetState.asset, assetState.assetId, underlyingAssets, underlyingAssetIds);

        derivedAM.setUnderlyingAssetsAmount(assetState.exposureAssetToUnderlyingAsset);

        derivedAM.setAssetInformation(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            assetState.underlyingAsset,
            assetState.underlyingAssetId,
            assetState.exposureAssetLast,
            assetState.lastUsdExposureAsset,
            assetState.lastExposureAssetToUnderlyingAsset
        );
    }

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

    // forge-lint: disable-next-item(mixed-case-variable)
    function setUnderlyingAssetModuleState(
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState
    ) internal {
        // Set mapping between underlying Asset and its asset module in the Registry.
        registry.setAssetModule(assetState.underlyingAsset, address(primaryAM));

        // Set max exposure of mocked Asset Module for Underlying assets.
        primaryAM.setExposure(
            assetState.creditor, assetState.underlyingAsset, assetState.underlyingAssetId, 0, type(uint112).max
        );

        setPrimaryAMOracle(
            assetState.underlyingAsset,
            assetState.underlyingAssetId,
            underlyingPMState.assetUnit,
            underlyingPMState.rateInUsd
        );
    }

    // forge-lint: disable-next-item(mixed-case-variable)
    function usdExposureToUnderlyingAsset(
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState
    ) internal pure returns (uint256) {
        return assetState.exposureAssetToUnderlyingAsset * underlyingPMState.rateInUsd / underlyingPMState.assetUnit;
    }

    // forge-lint: disable-next-item(mixed-case-variable)
    function givenValidState(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState
    )
        internal
        pure
        returns (DerivedAMProtocolState memory, DerivedAMAssetState memory, UnderlyingAssetModuleState memory)
    {
        // Given: id's are smaller or equal to type(uint96).max.
        assetState.assetId = bound(assetState.assetId, 0, type(uint96).max);
        assetState.underlyingAssetId = bound(assetState.underlyingAssetId, 0, type(uint96).max);

        // And: "exposure" of underlyingAsset is strictly smaller than its "maxExposure".
        assetState.exposureAssetToUnderlyingAsset =
            bound(assetState.exposureAssetToUnderlyingAsset, 1, type(uint64).max);

        // And: "usdExposureToUnderlyingAsset" does not overflow.
        underlyingPMState.assetUnit = uint64(bound(underlyingPMState.assetUnit, 1, type(uint64).max));
        underlyingPMState.rateInUsd = bound(
            underlyingPMState.rateInUsd,
            0,
            uint256(type(uint112).max - 1) * underlyingPMState.assetUnit / assetState.exposureAssetToUnderlyingAsset
        );

        // And: usd Value of protocol is bigger or equal to each individual usd value of an asset (Invariant).
        assetState.lastUsdExposureAsset =
            uint112(bound(assetState.lastUsdExposureAsset, 0, protocolState.lastUsdExposureProtocol));

        return (protocolState, assetState, underlyingPMState);
    }

    // forge-lint: disable-next-item(mixed-case-variable)
    function givenNonRevertingWithdrawal(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    )
        internal
        pure
        returns (
            DerivedAMProtocolState memory,
            DerivedAMAssetState memory,
            UnderlyingAssetModuleState memory,
            uint256,
            int256
        )
    {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);
        uint256 usdValue = usdExposureToUnderlyingAsset(assetState, underlyingPMState);

        // And: "usdExposureUpperAssetToAsset" does not overflow (unrealistic big values).
        if (usdValue != 0) {
            exposureUpperAssetToAsset = bound(exposureUpperAssetToAsset, 0, type(uint256).max / usdValue);
        }

        // Calculate exposureAsset.
        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            // Given: No overflow on exposureAsset.
            deltaExposureUpperAssetToAsset = int256(
                bound(uint256(deltaExposureUpperAssetToAsset), 0, type(uint112).max - assetState.exposureAssetLast)
            );

            exposureAsset = assetState.exposureAssetLast + uint256(deltaExposureUpperAssetToAsset);
        } else {
            // And: No overflow on negation most negative int256 (this overflows).
            vm.assume(deltaExposureUpperAssetToAsset > type(int256).min);

            if (uint256(-deltaExposureUpperAssetToAsset) < assetState.exposureAssetLast) {
                exposureAsset = uint256(assetState.exposureAssetLast) - uint256(-deltaExposureUpperAssetToAsset);
            }
        }

        if (usdValue >= assetState.lastUsdExposureAsset) {
            // And: "usdExposureProtocol" does not overflow (unrealistically big).
            protocolState.lastUsdExposureProtocol = uint112(
                bound(
                    protocolState.lastUsdExposureProtocol,
                    assetState.lastUsdExposureAsset,
                    type(uint112).max - (usdValue - assetState.lastUsdExposureAsset)
                )
            );
        }

        return (protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);
    }

    // forge-lint: disable-next-item(mixed-case-variable)
    function givenNonRevertingDeposit(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    )
        internal
        pure
        returns (
            DerivedAMProtocolState memory,
            DerivedAMAssetState memory,
            UnderlyingAssetModuleState memory,
            uint256,
            int256
        )
    {
        // Identical bounds as for Withdrawals.
        (protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset) =
            givenNonRevertingWithdrawal(
                protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
            );

        // And: "exposure" is strictly smaller than "maxExposure".
        uint256 usdValue = usdExposureToUnderlyingAsset(assetState, underlyingPMState);
        uint256 usdExposureProtocolExpected;
        if (usdValue >= assetState.lastUsdExposureAsset) {
            usdExposureProtocolExpected =
                protocolState.lastUsdExposureProtocol + (usdValue - assetState.lastUsdExposureAsset);
        } else {
            usdExposureProtocolExpected = protocolState.lastUsdExposureProtocol
                > assetState.lastUsdExposureAsset - usdValue
                ? protocolState.lastUsdExposureProtocol - (assetState.lastUsdExposureAsset - usdValue)
                : 0;
        }
        vm.assume(usdExposureProtocolExpected < type(uint112).max);
        protocolState.maxUsdExposureProtocol =
            uint112(bound(protocolState.maxUsdExposureProtocol, usdExposureProtocolExpected + 1, type(uint112).max));

        return (protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);
    }
}
