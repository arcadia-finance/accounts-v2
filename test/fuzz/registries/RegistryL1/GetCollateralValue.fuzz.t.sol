/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryL1_Fuzz_Test } from "./_RegistryL1.fuzz.t.sol";

import { Constants } from "../../../utils/Constants.sol";
import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getCollateralValue" of contract "RegistryL1".
 */
contract GetCollateralValue_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getCollateralValue_UnknownNumeraire(address numeraire) public {
        vm.assume(numeraire != address(0));
        vm.assume(!registry_.inRegistry(numeraire));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.stable2);
        assetAddresses[1] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert(abi.encodePacked("call to non-contract address ", vm.toString(address(0))));
        registry_.getCollateralValue(numeraire, address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_getCollateralValue(
        int64 rateToken1ToUsd,
        uint64 amountToken1,
        uint16 collateralFactor_,
        uint32 currentTime
    ) public {
        // Given: oracle staleness-check does not underflow.
        currentTime = uint32(bound(currentTime, 2 days, type(uint32).max));
        vm.warp(currentTime);

        // And: Risk parameters are set.
        vm.prank(creditorUsd.riskManager());
        registry_.setRiskParameters(address(creditorUsd), 0, type(uint64).max);

        vm.assume(collateralFactor_ <= AssetValuationLib.ONE_4);
        vm.assume(rateToken1ToUsd > 0);

        vm.prank(users.transmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);

        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, amountToken1, oracleToken1ToUsdArr);
        vm.assume(token1ValueInUsd > 0);

        vm.prank(users.riskManager);
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            collateralFactor_,
            uint16(AssetValuationLib.ONE_4)
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken1;

        uint256 actualCollateralValue =
            registry_.getCollateralValue(address(0), address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        uint256 expectedCollateralValue = token1ValueInUsd * collateralFactor_ / 10_000;

        assertEq(expectedCollateralValue, actualCollateralValue);
    }
}
