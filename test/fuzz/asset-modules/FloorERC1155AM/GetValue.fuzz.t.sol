/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FloorERC1155AM_Fuzz_Test } from "./_FloorERC1155AM.fuzz.t.sol";

import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

import { Constants } from "../../../utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "FloorERC1155AM".
 */
contract GetValue_FloorERC1155AM_Fuzz_Test is FloorERC1155AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155AM_Fuzz_Test.setUp();

        // Add Sft2 (which has an oracle directly to usd).
        vm.prank(users.creatorAddress);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 1, oraclesSft2ToUsd);

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft2), 1, type(uint112).max, 0, 0
        );
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValue_Overflow(uint256 amountSft2, uint256 rateSft2ToUsd) public {
        // No Overflow Registry.
        rateSft2ToUsd = bound(rateSft2ToUsd, 1, type(uint256).max / 10 ** (36 - Constants.erc1155OracleDecimals));

        // Overflow Asset Module (test-case).
        amountSft2 = bound(
            amountSft2,
            type(uint256).max / rateSft2ToUsd / 10 ** (18 - Constants.erc1155OracleDecimals) + 1,
            type(uint256).max
        );

        vm.prank(users.defaultTransmitter);
        mockOracles.sft2ToUsd.transmit(int256(rateSft2ToUsd));

        // When: getValue called
        // Then: getValue should be reverted
        vm.expectRevert(bytes(""));
        floorERC1155AM.getValue(address(creditorUsd), address(mockERC1155.sft2), 1, amountSft2);
    }

    function testFuzz_Success_getValue(uint256 amountSft2, uint256 rateSft2ToUsd) public {
        // No Overflow Registry.
        rateSft2ToUsd = bound(rateSft2ToUsd, 1, type(uint256).max / 10 ** (36 - Constants.erc1155OracleDecimals));

        // No Overflow Asset Module.
        if (rateSft2ToUsd != 0) {
            amountSft2 =
                bound(amountSft2, 0, type(uint256).max / rateSft2ToUsd / 10 ** (18 - Constants.erc1155OracleDecimals));
        }

        uint256 expectedValueInUsd = amountSft2 * rateSft2ToUsd * 10 ** (18 - Constants.erc1155OracleDecimals);

        vm.prank(users.defaultTransmitter);
        mockOracles.sft2ToUsd.transmit(int256(rateSft2ToUsd));

        // When: getValue called
        (uint256 actualValueInUsd,,) =
            floorERC1155AM.getValue(address(creditorUsd), address(mockERC1155.sft2), 1, amountSft2);

        // Then: actualValueInUsd should be equal to expectedValueInUsd
        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
