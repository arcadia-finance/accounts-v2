/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test, Constants } from "../Base_IntegrationAndUnit.t.sol";

contract OracleHub_Integration_Test is Base_IntegrationAndUnit_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_getRate_NegativeRate(int256 rateToken1ToUsd) public {
        // Given: oracleToken1ToUsdDecimals less than equal to 18, rateToken1ToUsd less than equal to max uint256 value,
        // rateToken1ToUsd is less than max uint256 value divided by WAD
        vm.assume(rateToken1ToUsd < 0);

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);
        vm.stopPrank();

        address[] memory oracleToken1ToUsdArr = new address[](1);
        oracleToken1ToUsdArr[0] = address(mockOracles.token1ToUsd);

        vm.expectRevert("OH_GR: Negative Rate");
        oracleHub.getRateInUsd(oracleToken1ToUsdArr);
    }
}