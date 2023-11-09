/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { StandardERC20PricingModule_Fuzz_Test } from "./_StandardERC20PricingModule.fuzz.t.sol";

import { Constants } from "../../../utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "StandardERC20PricingModule".
 */
contract GetValue_StandardERC20PricingModule_Fuzz_Test is StandardERC20PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC20PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValue_Overflow(uint256 rateToken1ToUsdNew, uint256 amountToken1) public {
        // No Overflow OracleHub
        rateToken1ToUsdNew =
            bound(rateToken1ToUsdNew, 1, type(uint256).max / 10 ** (36 - Constants.tokenOracleDecimals));

        // Overflow Pricing Module (test-case).
        amountToken1 = bound(
            amountToken1,
            type(uint256).max / rateToken1ToUsdNew / 10 ** (18 - Constants.tokenOracleDecimals) + 1,
            type(uint256).max
        );

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsdNew));

        vm.expectRevert(bytes(""));
        erc20PricingModule.getValue(address(creditorUsd), address(mockERC20.token1), 0, amountToken1);
    }

    function testFuzz_Success_getValue(uint256 rateToken1ToUsdNew, uint256 amountToken1) public {
        // No Overflow OracleHub
        rateToken1ToUsdNew =
            bound(rateToken1ToUsdNew, 1, type(uint256).max / 10 ** (36 - Constants.tokenOracleDecimals));

        // No Overflow Pricing Module.
        if (rateToken1ToUsdNew != 0) {
            amountToken1 = bound(
                amountToken1, 0, type(uint256).max / rateToken1ToUsdNew / 10 ** (18 - Constants.tokenOracleDecimals)
            );
        }

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsdNew));

        uint256 expectedValueInUsd = amountToken1 * rateToken1ToUsdNew * 10 ** (18 - Constants.tokenOracleDecimals)
            / 10 ** Constants.tokenDecimals;

        (uint256 actualValueInUsd,,) =
            erc20PricingModule.getValue(address(creditorUsd), address(mockERC20.token1), 0, amountToken1);

        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
