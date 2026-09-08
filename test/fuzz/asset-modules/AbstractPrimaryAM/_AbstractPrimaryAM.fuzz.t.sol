/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { OracleModuleMock } from "../../../utils/mocks/oracle-modules/OracleModuleMock.sol";
import { PrimaryAMMock } from "../../../utils/mocks/asset-modules/PrimaryAMMock.sol";

/**
 * @notice Common logic needed by all "AbstractPrimaryAM" fuzz tests.
 */
abstract contract AbstractPrimaryAM_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    uint256 internal constant INT256_MAX = 2 ** 255 - 1;
    // Negating the true minimum of 2 ** 255 overflows, so this stops one below it.
    uint256 internal constant INT256_MIN = 2 ** 255 - 1;

    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-next-item(pascal-case-struct)
    struct PrimaryAMAssetState {
        address creditor;
        address asset;
        uint96 assetId;
        uint112 exposureAssetLast;
        uint112 exposureAssetMax;
        uint64 assetUnit;
        uint256 rateInUsd;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    PrimaryAMMock internal assetModule;
    OracleModuleMock internal oracleModule;

    uint256 internal constant PRIMARY_AM_ORACLE_ID = 999;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.owner);
        assetModule = new PrimaryAMMock(users.owner, address(registry), 0);

        oracleModule = new OracleModuleMock(users.owner, address(registry));
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

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
        assetModule.setAssetInformation(asset, assetId, assetUnit, BitPackingLib.pack(baseToQuoteAsset, oracleIds));
    }

    // forge-lint: disable-next-item(mixed-case-function,unsafe-typecast)
    function setPrimaryAMAssetState(PrimaryAMAssetState memory assetState) internal {
        assetModule.setExposure(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            assetState.exposureAssetLast,
            assetState.exposureAssetMax
        );

        setPrimaryAMOracle(assetState.asset, assetState.assetId, assetState.assetUnit, assetState.rateInUsd);
    }
}
