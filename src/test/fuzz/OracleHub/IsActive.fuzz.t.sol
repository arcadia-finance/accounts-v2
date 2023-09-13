/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, OracleHub_Fuzz_Test } from "./OracleHub.fuzz.t.sol";

import { OracleHub } from "../../../OracleHub.sol";

/**
 * @notice Fuzz tests for the function "isActive" of contract "OracleHub".
 */
contract IsActive_OracleHub_Fuzz_Test is OracleHub_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        OracleHub_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Pass_isActive_Active(address oracle) public {
        vm.assume(oracle != address(mockOracles.token1ToUsd));
        vm.assume(oracle != address(mockOracles.token2ToUsd));
        vm.assume(oracle != address(mockOracles.stable1ToUsd));
        vm.assume(oracle != address(mockOracles.stable2ToUsd));
        assertFalse(oracleHub.isActive(address(oracle)));
    }

    function testFuzz_Pass_isActive_NotActive() public {
        vm.prank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );

        assertTrue(oracleHub.isActive(address(mockOracles.token3ToToken4)));
    }
}
