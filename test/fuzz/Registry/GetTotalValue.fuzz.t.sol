/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

import { ArcadiaOracle } from "../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../src/libraries/BitPackingLib.sol";
import { Constants } from "../../utils/Constants.sol";
import { ERC20Mock } from "../../utils/mocks/tokens/ERC20Mock.sol";
import { AssetModule } from "../../../src/asset-modules/abstracts/AbstractAM.sol";

/**
 * @notice Fuzz tests for the function "getTotalValue" of contract "Registry".
 */
contract GetTotalValue_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getTotalValue_SequencerDown(
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
        registryExtension.getTotalValue(numeraire, address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_getTotalValue_GracePeriodNotPassed(
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
        registryExtension.getTotalValue(numeraire, address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_getTotalValue_UnknownNumeraire(address numeraire) public {
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
        registryExtension.getTotalValue(numeraire, address(creditorToken1), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_getTotalValue_CalculateValueInNumeraireFromValueInUsdOverflow(
        uint256 rateToken1ToUsd,
        uint256 amountToken2,
        uint8 token2Decimals
    ) public {
        vm.assume(token2Decimals < Constants.tokenOracleDecimals);
        vm.assume(rateToken1ToUsd <= uint256(type(int256).max));
        vm.assume(rateToken1ToUsd > 0);
        vm.assume(
            amountToken2
                > ((type(uint256).max / uint256(rates.token2ToUsd) / Constants.WAD) * 10 ** Constants.tokenOracleDecimals)
                    / 10 ** (Constants.tokenOracleDecimals - token2Decimals)
        );

        ArcadiaOracle oracle = initMockedOracle(0, "LINK / USD");
        vm.prank(users.defaultTransmitter);
        oracle.transmit(0);
        vm.startPrank(users.creatorAddress);
        mockERC20.token2 = new ERC20Mock("TOKEN2", "T2", token2Decimals);

        uint80 oracleId = uint80(chainlinkOM.addOracle(address(oracle), "TOKEN2", "USD", 2 days));
        uint80[] memory oracleAssetToUsdArr = new uint80[](1);
        oracleAssetToUsdArr[0] = oracleId;

        erc20AssetModule.addAsset(address(mockERC20.token2), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAssetToUsdArr));
        vm.stopPrank();
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC20.token2), 0, type(uint112).max, 0, 0
        );

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd));
        oracle.transmit(int256(rates.token2ToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        // Then: getTotalValue should revert with arithmetic overflow
        vm.expectRevert(bytes(""));
        registryExtension.getTotalValue(
            address(mockERC20.token1), address(creditorToken1), assetAddresses, assetIds, assetAmounts
        );
    }

    function testFuzz_Revert_getTotalValue_CalculateValueInNumeraireFromValueInUsdWithRateZero(uint256 amountToken2)
        public
    {
        vm.assume(amountToken2 > 0);

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(0));
        mockOracles.token2ToUsd.transmit(int256(rates.stable2ToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        // Then: getTotalValue should revert
        vm.expectRevert(bytes(""));
        registryExtension.getTotalValue(
            address(mockERC20.token1), address(creditorToken1), assetAddresses, assetIds, assetAmounts
        );
    }

    function testFuzz_Success_getTotalValue(uint32 gracePeriod, uint32 startedAt, uint32 currentTime) public {
        // Given: startedAt does not underflow.
        // And: oracle staleness-check does not underflow.
        currentTime = uint32(bound(currentTime, 2 days, type(uint32).max));
        vm.warp(currentTime);

        // And: Oracles are not stale.
        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd));
        mockOracles.token2ToUsd.transmit(int256(rates.token2ToUsd));
        mockOracles.nft1ToToken1.transmit(int256(rates.nft1ToToken1));
        vm.stopPrank();

        // And: Sequencer is online.
        startedAt = uint32(bound(startedAt, 0, currentTime));
        sequencerUptimeOracle.setLatestRoundData(0, startedAt);

        // And: Grace period did pass.
        gracePeriod = uint32(bound(gracePeriod, 0, currentTime - startedAt));
        vm.prank(creditorToken1.riskManager());
        registryExtension.setRiskParameters(address(creditorToken1), 0, gracePeriod, type(uint64).max);

        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.token2);
        assetAddresses[2] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.tokenDecimals;
        assetAmounts[1] = 10 ** Constants.tokenDecimals;
        assetAmounts[2] = 1;

        // Numeraire for actualTotalValue is set to mockERC20.token1
        uint256 actualTotalValue = registryExtension.getTotalValue(
            address(mockERC20.token1), address(creditorToken1), assetAddresses, assetIds, assetAmounts
        );

        uint256 token1ValueInToken1 = assetAmounts[0];
        uint256 token2ValueInToken1 = convertUsdToNumeraire(
            Constants.tokenDecimals,
            convertAssetToUsd(Constants.tokenDecimals, assetAmounts[1], oracleToken2ToUsdArr),
            rates.token1ToUsd,
            Constants.tokenOracleDecimals
        );
        uint256 nft1ValueInToken1 = convertUsdToNumeraire(
            Constants.tokenDecimals,
            convertAssetToUsd(0, assetAmounts[2], oracleNft1ToToken1ToUsd),
            rates.token1ToUsd,
            Constants.tokenOracleDecimals
        );

        uint256 expectedTotalValue = token1ValueInToken1 + token2ValueInToken1 + nft1ValueInToken1;

        assertEq(expectedTotalValue, actualTotalValue);
    }

    function testFuzz_Success_getTotalValue_CalculateValueInNumeraireFromValueInUsd_token2With18Decimals(
        uint256 rateToken1ToUsd,
        uint256 amountToken2
    ) public {
        rateToken1ToUsd = bound(rateToken1ToUsd, 1, type(uint256).max / 10 ** (36 - Constants.tokenOracleDecimals));

        vm.assume(
            amountToken2
                <= type(uint256).max / uint256(rates.token2ToUsd) / Constants.WAD
                    / 10 ** (Constants.tokenOracleDecimals - Constants.tokenOracleDecimals)
        );
        vm.assume(
            amountToken2
                <= (
                    ((type(uint256).max / uint256(rates.token2ToUsd) / Constants.WAD) * 10 ** Constants.tokenOracleDecimals)
                        / 10 ** Constants.tokenOracleDecimals
                ) * 10 ** Constants.tokenDecimals
        );

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        uint256 actualTotalValue = registryExtension.getTotalValue(
            address(mockERC20.token1), address(creditorToken1), assetAddresses, assetIds, assetAmounts
        );

        uint256 token2ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, amountToken2, oracleToken2ToUsdArr);
        uint256 token2ValueInToken1 = convertUsdToNumeraire(
            Constants.tokenDecimals, token2ValueInUsd, rateToken1ToUsd, Constants.tokenOracleDecimals
        );

        uint256 expectedValue = token2ValueInToken1;

        // Then: expectedTotalValue should be equal to actualTotalValue
        assertEq(expectedValue, actualTotalValue);
    }

    function testFuzz_Success_getTotalValue_CalculateValueInNumeraireFromValueInUsd_token2With6decimals(
        uint256 rateToken1ToUsd,
        uint128 amountToken2
    ) public {
        // Here it's safe to consider a max value of uint128.max for amountToken2, as we tested for overflow on previous related test.
        // Objective is to test if calculation hold true with different token decimals (in this case mockERC20.stable tokens have 6 decimals)
        rateToken1ToUsd = bound(rateToken1ToUsd, 1, type(uint256).max / 10 ** (36 - Constants.tokenOracleDecimals));

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.stable2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        uint256 actualTotalValue = registryExtension.getTotalValue(
            address(mockERC20.token1), address(creditorToken1), assetAddresses, assetIds, assetAmounts
        );

        uint256 token2ValueInUsd = convertAssetToUsd(Constants.stableDecimals, amountToken2, oracleStable2ToUsdArr);
        uint256 token2ValueInToken1 = convertUsdToNumeraire(
            Constants.tokenDecimals, token2ValueInUsd, rateToken1ToUsd, Constants.tokenOracleDecimals
        );

        uint256 expectedValue = token2ValueInToken1;

        // Then: expectedTotalValue should be equal to actualTotalValue
        assertEq(expectedValue, actualTotalValue);
    }
}
