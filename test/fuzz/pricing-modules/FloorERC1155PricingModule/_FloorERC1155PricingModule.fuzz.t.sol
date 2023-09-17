/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { OracleHub } from "../../../../src/OracleHub.sol";
import { RiskConstants } from "../../../../src/libraries/RiskConstants.sol";

/**
 * @notice Common logic needed by all "FloorERC1155PricingModule" fuzz tests.
 */
abstract contract FloorERC1155PricingModule_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    uint16 internal collateralFactor = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    uint16 internal liquidationFactor = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;

    address[] internal oracleSft2ToUsdArr = new address[](1);

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.erc1155OracleDecimals),
                baseAsset: "SFT2",
                quoteAsset: "USD",
                oracle: address(mockOracles.sft2ToUsd),
                baseAssetAddress: address(mockERC1155.sft2),
                isActive: true
            })
        );

        oracleSft2ToUsdArr[0] = address(mockOracles.sft2ToUsd);
    }
}
