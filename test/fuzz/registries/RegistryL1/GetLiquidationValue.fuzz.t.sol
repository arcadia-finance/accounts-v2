/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryL1_Fuzz_Test } from "./_RegistryL1.fuzz.t.sol";

import { Constants } from "../../../utils/Constants.sol";
import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getLiquidationValue" of contract "RegistryL1".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract GetLiquidationValue_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getLiquidationValue_UnknownNumeraire(address numeraire) public {
        vm.assume(numeraire != address(0));
        vm.assume(!registry_.inRegistry(numeraire));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token2);
        assetAddresses[1] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 1;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 1;

        vm.expectRevert(bytes(""));
        registry_.getLiquidationValue(numeraire, address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_getLiquidationValue(
        int64 rateToken1ToUsd,
        uint64 amountToken1,
        uint16 liquidationFactor_,
        uint32 currentTime
    ) public {
        // Given: oracle staleness-check does not underflow.
        // forge-lint: disable-next-item(unsafe-typecast)
        currentTime = uint32(bound(currentTime, 2 days, type(uint32).max));
        vm.warp(currentTime);

        // And: Risk parameters are set.
        vm.prank(creditorUsd.riskManager());
        registry_.setRiskParameters(address(creditorUsd), 0, type(uint64).max);

        liquidationFactor_ = uint16(bound(liquidationFactor_, 0, AssetValuationLib.ONE_4));
        rateToken1ToUsd = int64(bound(rateToken1ToUsd, 1, type(int64).max));

        vm.prank(users.transmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);

        // And: The usd value of the asset is non-zero.
        amountToken1 = uint64(
            bound(
                amountToken1,
                (10 ** (Constants.TOKEN_ORACLE_DECIMALS + Constants.TOKEN_DECIMALS) / Constants.WAD - 1)
                    / uint256(int256(rateToken1ToUsd)) + 1,
                type(uint64).max
            )
        );

        uint256 token1ValueInUsd = convertAssetToUsd(Constants.TOKEN_DECIMALS, amountToken1, oracleToken1ToUsdArr);

        vm.prank(users.riskManager);
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC20.token1), 0, type(uint112).max, 0, liquidationFactor_
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken1;

        uint256 actualLiquidationValue =
            registry_.getLiquidationValue(address(0), address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        uint256 expectedLiquidationValue = token1ValueInUsd * liquidationFactor_ / 10_000;

        assertEq(expectedLiquidationValue, actualLiquidationValue);
    }
}
