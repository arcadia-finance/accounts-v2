/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20PrimaryAM_Fuzz_Test } from "./_ERC20PrimaryAM.fuzz.t.sol";

import { Constants } from "../../../utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "ERC20PrimaryAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
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
            bound(rateToken1ToUsdNew, 1, type(uint256).max / 10 ** (36 - Constants.TOKEN_ORACLE_DECIMALS));

        // Overflow Asset Module (test-case).
        amountToken1 = bound(
            amountToken1,
            type(uint256).max / rateToken1ToUsdNew / 10 ** (18 - Constants.TOKEN_ORACLE_DECIMALS) + 1,
            type(uint256).max
        );

        vm.prank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsdNew));

        vm.expectRevert(bytes(""));
        erc20AM.getValue(address(creditorUsd), address(mockERC20.token1), 0, amountToken1);
    }

    function testFuzz_Success_getValue(uint256 rateToken1ToUsdNew, uint256 amountToken1) public {
        // No Overflow Registry
        rateToken1ToUsdNew =
            bound(rateToken1ToUsdNew, 1, type(uint256).max / 10 ** (36 - Constants.TOKEN_ORACLE_DECIMALS));

        // No Overflow Asset Module.
        if (rateToken1ToUsdNew != 0) {
            amountToken1 = bound(
                amountToken1, 0, type(uint256).max / rateToken1ToUsdNew / 10 ** (18 - Constants.TOKEN_ORACLE_DECIMALS)
            );
        }

        vm.prank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsdNew));

        uint256 expectedValueInUsd = amountToken1 * rateToken1ToUsdNew * 10 ** (18 - Constants.TOKEN_ORACLE_DECIMALS)
            / 10 ** Constants.TOKEN_DECIMALS;

        (uint256 actualValueInUsd,,) =
            erc20AM.getValue(address(creditorUsd), address(mockERC20.token1), 0, amountToken1);

        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
