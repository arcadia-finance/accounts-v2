/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20PrimaryAM_Fuzz_Test } from "./_ERC20PrimaryAM.fuzz.t.sol";

import { Constants } from "../../../utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "ERC20PrimaryAM".
 */
contract GetValue_ERC20PrimaryAM_Fuzz_Test is ERC20PrimaryAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ERC20PrimaryAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValue_Overflow(uint256 rateToken1ToUsdNew, uint256 amountToken1) public {
        // No Overflow Registry
        rateToken1ToUsdNew =
            bound(rateToken1ToUsdNew, 1, type(uint256).max / 10 ** (36 - Constants.tokenOracleDecimals));

        // Overflow Asset Module (test-case).
        amountToken1 = bound(
            amountToken1,
            type(uint256).max / rateToken1ToUsdNew / 10 ** (18 - Constants.tokenOracleDecimals) + 1,
            type(uint256).max
        );

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsdNew));

        vm.expectRevert(bytes(""));
        erc20AssetModule.getValue(address(creditorUsd), address(mockERC20.token1), 0, amountToken1);
    }

    function testFuzz_Success_getValue(uint256 rateToken1ToUsdNew, uint256 amountToken1) public {
        // No Overflow Registry
        rateToken1ToUsdNew =
            bound(rateToken1ToUsdNew, 1, type(uint256).max / 10 ** (36 - Constants.tokenOracleDecimals));

        // No Overflow Asset Module.
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
            erc20AssetModule.getValue(address(creditorUsd), address(mockERC20.token1), 0, amountToken1);

        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
