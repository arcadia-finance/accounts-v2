/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { OracleHub } from "../../../../src/OracleHub.sol";
import { RiskConstants } from "../../../../src/utils/RiskConstants.sol";

/**
 * @notice Common logic needed by all "StandardERC20PricingModule" fuzz tests.
 */
abstract contract StandardERC20PricingModule_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    uint16 internal collateralFactor = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    uint16 internal liquidationFactor = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;

    address[] internal oracleToken4ToUsdArr = new address[](1);

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );

        oracleToken4ToUsdArr[0] = address(mockOracles.token4ToUsd);
    }
}
