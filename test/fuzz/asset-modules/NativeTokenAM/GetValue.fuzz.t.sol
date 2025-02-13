/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Constants } from "../../../utils/Constants.sol";
import { NativeTokenAM_Fuzz_Test } from "./_NativeTokenAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "NativeTokenAM".
 */
contract GetValue_NativeTokenAM_Fuzz_Test is NativeTokenAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        NativeTokenAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValue_Overflow(address asset, uint256 rateToken1ToUsdNew, uint256 amount) public {
        vm.prank(users.owner);
        nativeTokenAM.addAsset(asset, oraclesNativeTokenToUsd);

        // No Overflow Registry
        rateToken1ToUsdNew =
            bound(rateToken1ToUsdNew, 1, type(uint256).max / 10 ** (36 - Constants.tokenOracleDecimals));

        // Overflow Asset Module (test-case).
        amount = bound(
            amount,
            type(uint256).max / rateToken1ToUsdNew / 10 ** (18 - Constants.tokenOracleDecimals) + 1,
            type(uint256).max
        );

        vm.prank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsdNew));

        vm.expectRevert(bytes(""));
        nativeTokenAM.getValue(address(creditorUsd), asset, 0, amount);
    }

    function testFuzz_Success_getValue(address asset, uint256 rateToken1ToUsdNew, uint256 amount) public {
        vm.prank(users.owner);
        nativeTokenAM.addAsset(asset, oraclesNativeTokenToUsd);

        // No Overflow Registry
        rateToken1ToUsdNew =
            bound(rateToken1ToUsdNew, 1, type(uint256).max / 10 ** (36 - Constants.tokenOracleDecimals));

        // No Overflow Asset Module.
        if (rateToken1ToUsdNew != 0) {
            amount =
                bound(amount, 0, type(uint256).max / rateToken1ToUsdNew / 10 ** (18 - Constants.tokenOracleDecimals));
        }

        vm.prank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsdNew));

        uint256 expectedValueInUsd = amount * rateToken1ToUsdNew * 10 ** (18 - Constants.tokenOracleDecimals) / 1e18;

        (uint256 actualValueInUsd,,) = nativeTokenAM.getValue(address(creditorUsd), asset, 0, amount);

        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
