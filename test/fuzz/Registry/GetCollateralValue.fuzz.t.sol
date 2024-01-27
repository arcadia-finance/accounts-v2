/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

import { Constants } from "../../utils/Constants.sol";
import { AssetModule } from "../../../src/asset-modules/abstracts/AbstractAM.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getCollateralValue" of contract "Registry".
 */
contract GetCollateralValue_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getCollateralValue_SequencerDown(
        address numeraire,
        address asset,
        uint96 assetId,
        uint256 assetAmount,
        uint64 gracePeriod,
        uint256 startedAt,
        uint32 currentTime
    ) public {
        // Given: A random time.
        vm.warp(currentTime);

        // And: Sequencer is down.
        sequencerUptimeOracle.setLatestRoundData(1, startedAt);

        // And: A random gracePeriod.
        vm.prank(creditorUsd.riskManager());
        registryExtension.setRiskParameters(address(creditorUsd), 0, gracePeriod, type(uint64).max);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        vm.expectRevert(RegistryErrors.SequencerDown.selector);
        registryExtension.getCollateralValue(numeraire, address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_getCollateralValue_GracePeriodNotPassed(
        address numeraire,
        address asset,
        uint96 assetId,
        uint256 assetAmount,
        uint32 gracePeriod,
        uint32 startedAt,
        uint32 currentTime
    ) public {
        // Given: A random time.
        vm.warp(currentTime);

        // And: Sequencer is online.
        startedAt = uint32(bound(startedAt, 0, currentTime));
        sequencerUptimeOracle.setLatestRoundData(0, startedAt);

        // And: Grace period did not pass.
        vm.assume(currentTime - startedAt < type(uint32).max);
        gracePeriod = uint32(bound(gracePeriod, currentTime - startedAt + 1, type(uint32).max));
        vm.prank(creditorUsd.riskManager());
        registryExtension.setRiskParameters(address(creditorUsd), 0, gracePeriod, type(uint64).max);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        vm.expectRevert(RegistryErrors.SequencerDown.selector);
        registryExtension.getCollateralValue(numeraire, address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_getCollateralValue_UnknownNumeraire(address numeraire) public {
        vm.assume(numeraire != address(0));
        vm.assume(!registryExtension.inRegistry(numeraire));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.stable2);
        assetAddresses[1] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert(bytes(""));
        registryExtension.getCollateralValue(numeraire, address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_getCollateralValue(
        int64 rateToken1ToUsd,
        uint64 amountToken1,
        uint16 collateralFactor_,
        uint32 gracePeriod,
        uint32 startedAt,
        uint32 currentTime
    ) public {
        // Given: startedAt does not underflow.
        // And: oracle staleness-check does not underflow.
        currentTime = uint32(bound(currentTime, 2 days, type(uint32).max));
        vm.warp(currentTime);

        // And: Sequencer is online.
        startedAt = uint32(bound(startedAt, 0, currentTime));
        sequencerUptimeOracle.setLatestRoundData(0, startedAt);

        // And: Grace period did pass.
        gracePeriod = uint32(bound(gracePeriod, 0, currentTime - startedAt));
        vm.prank(creditorUsd.riskManager());
        registryExtension.setRiskParameters(address(creditorUsd), 0, gracePeriod, type(uint64).max);

        vm.assume(collateralFactor_ <= AssetValuationLib.ONE_4);
        vm.assume(rateToken1ToUsd > 0);

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);

        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, amountToken1, oracleToken1ToUsdArr);
        vm.assume(token1ValueInUsd > 0);

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
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

        uint256 actualCollateralValue = registryExtension.getCollateralValue(
            address(0), address(creditorUsd), assetAddresses, assetIds, assetAmounts
        );

        uint256 expectedCollateralValue = token1ValueInUsd * collateralFactor_ / 10_000;

        assertEq(expectedCollateralValue, actualCollateralValue);
    }
}
