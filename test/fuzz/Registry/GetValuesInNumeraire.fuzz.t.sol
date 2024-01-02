/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

import { stdError } from "../../../lib/forge-std/src/StdError.sol";

import { CompareArrays } from "../../utils/CompareArrays.sol";
import { Constants } from "../../utils/Constants.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getValuesInNumeraire" of contract "Registry".
 */
contract GetValuesInNumeraire_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValuesInNumeraire_SequencerDown(
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
        registryExtension.getValuesInNumeraire(numeraire, address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_getValuesInNumeraire_GracePeriodNotPassed(
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
        registryExtension.getValuesInNumeraire(numeraire, address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_getValuesInNumeraire_UnknownAsset() public {
        // Should revert here as mockERC20.token3 was not added to an asset module
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.token3);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert(bytes(""));
        registryExtension.getValuesInNumeraire(address(0), address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_getValuesInNumeraire_UnknownNumeraireAddress(address numeraire) public {
        vm.assume(numeraire != address(0));
        vm.assume(!registryExtension.inRegistry(numeraire));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.stable2);
        assetAddresses[1] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert(bytes(""));
        registryExtension.getValuesInNumeraire(numeraire, address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_getValuesInNumeraire_NumeraireIsUsd(
        uint32 gracePeriod,
        uint32 startedAt,
        uint32 currentTime
    ) public {
        // Given: startedAt does not underflow.
        // And: oracle staleness-check does not underflow.
        currentTime = uint32(bound(currentTime, 2 days, type(uint32).max));
        vm.warp(currentTime);

        // And: Oracles are not stale.
        vm.startPrank(users.defaultTransmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd));
        mockOracles.nft1ToToken1.transmit(int256(rates.nft1ToToken1));
        vm.stopPrank();

        // And: Sequencer is online.
        startedAt = uint32(bound(startedAt, 0, currentTime));
        sequencerUptimeOracle.setLatestRoundData(0, startedAt);

        // And: Grace period did pass.
        gracePeriod = uint32(bound(gracePeriod, 0, currentTime - startedAt));
        vm.prank(creditorUsd.riskManager());
        registryExtension.setRiskParameters(address(creditorUsd), 0, gracePeriod, type(uint64).max);

        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.stable1);
        assetAddresses[1] = address(mockERC20.token1);
        assetAddresses[2] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.stableDecimals;
        assetAmounts[1] = 10 ** Constants.tokenDecimals;
        assetAmounts[2] = 1;

        AssetValueAndRiskFactors[] memory actualValuesPerAsset = registryExtension.getValuesInNumeraire(
            address(0), address(creditorUsd), assetAddresses, assetIds, assetAmounts
        );

        uint256 stable1ValueInUsd = convertAssetToUsd(Constants.stableDecimals, assetAmounts[0], oracleStable1ToUsdArr);
        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, assetAmounts[1], oracleToken1ToUsdArr);
        uint256 nft1ValueInUsd = convertAssetToUsd(0, assetAmounts[2], oracleNft1ToToken1ToUsd);

        uint256[] memory expectedListOfValuesPerAsset = new uint256[](3);
        expectedListOfValuesPerAsset[0] = stable1ValueInUsd;
        expectedListOfValuesPerAsset[1] = token1ValueInUsd;
        expectedListOfValuesPerAsset[2] = nft1ValueInUsd;

        uint256[] memory actualListOfValuesPerAsset = new uint256[](3);
        for (uint256 i; i < actualValuesPerAsset.length; ++i) {
            actualListOfValuesPerAsset[i] = actualValuesPerAsset[i].assetValue;
        }

        assertTrue(CompareArrays.compareArrays(expectedListOfValuesPerAsset, actualListOfValuesPerAsset));
    }

    function testFuzz_Success_getValuesInNumeraire_NumeraireIsNotUsd(
        uint32 gracePeriod,
        uint32 startedAt,
        uint32 currentTime
    ) public {
        // Given: startedAt does not underflow.
        // And: oracle staleness-check does not underflow.
        currentTime = uint32(bound(currentTime, 2 days, type(uint32).max));
        vm.warp(currentTime);

        // And: Oracles are not stale.
        vm.startPrank(users.defaultTransmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd));
        mockOracles.nft1ToToken1.transmit(int256(rates.nft1ToToken1));
        vm.stopPrank();

        // And: Sequencer is online.
        startedAt = uint32(bound(startedAt, 0, currentTime));
        sequencerUptimeOracle.setLatestRoundData(0, startedAt);

        // And: Grace period did pass.
        gracePeriod = uint32(bound(gracePeriod, 0, currentTime - startedAt));
        vm.prank(creditorUsd.riskManager());
        registryExtension.setRiskParameters(address(creditorUsd), 0, gracePeriod, type(uint64).max);

        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.stable1);
        assetAddresses[1] = address(mockERC20.token1);
        assetAddresses[2] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.stableDecimals;
        assetAmounts[1] = 10 ** Constants.tokenDecimals;
        assetAmounts[2] = 1;

        AssetValueAndRiskFactors[] memory actualValuesPerAsset = registryExtension.getValuesInNumeraire(
            address(mockERC20.token1), address(creditorUsd), assetAddresses, assetIds, assetAmounts
        );

        uint256 stable1ValueInUsd = convertAssetToUsd(Constants.stableDecimals, assetAmounts[0], oracleStable1ToUsdArr);
        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, assetAmounts[1], oracleToken1ToUsdArr);
        uint256 nft1ValueInUsd = convertAssetToUsd(0, assetAmounts[2], oracleNft1ToToken1ToUsd);

        uint256 stable1ValueInBCurrency = convertUsdToNumeraire(
            Constants.tokenDecimals, stable1ValueInUsd, rates.token1ToUsd, Constants.tokenOracleDecimals
        );
        uint256 token1ValueInBCurrency = convertUsdToNumeraire(
            Constants.tokenDecimals, token1ValueInUsd, rates.token1ToUsd, Constants.tokenOracleDecimals
        );
        uint256 nft1ValueInBCurrency = convertUsdToNumeraire(
            Constants.tokenDecimals, nft1ValueInUsd, rates.token1ToUsd, Constants.tokenOracleDecimals
        );

        uint256[] memory expectedListOfValuesPerAsset = new uint256[](3);
        expectedListOfValuesPerAsset[0] = stable1ValueInBCurrency;
        expectedListOfValuesPerAsset[1] = token1ValueInBCurrency;
        expectedListOfValuesPerAsset[2] = nft1ValueInBCurrency;

        uint256[] memory actualListOfValuesPerAsset = new uint256[](3);
        for (uint256 i; i < actualValuesPerAsset.length; ++i) {
            actualListOfValuesPerAsset[i] = actualValuesPerAsset[i].assetValue;
        }

        assertTrue(CompareArrays.compareArrays(expectedListOfValuesPerAsset, actualListOfValuesPerAsset));
    }
}
