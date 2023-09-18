/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, OracleHub_Fuzz_Test } from "./_OracleHub.fuzz.t.sol";

import { OracleHub } from "../../../src/OracleHub.sol";

/**
 * @notice Fuzz tests for the function "checkOracleSequence" of contract "OracleHub".
 */
contract CheckOracleSequence_OracleHub_Fuzz_Test is OracleHub_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        OracleHub_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_checkOracleSequence_ZeroOracles(address asset) public {
        address[] memory oraclesSequence = new address[](0);

        vm.expectRevert("OH_COS: Min 1 Oracle");
        oracleHub.checkOracleSequence(oraclesSequence, asset);
    }

    function testFuzz_Revert_checkOracleSequence_MoreThanThreeOracles(address asset) public {
        address[] memory oraclesSequence = new address[](4);

        vm.expectRevert("OH_COS: Max 3 Oracles");
        oracleHub.checkOracleSequence(oraclesSequence, asset);
    }

    function testFuzz_Revert_checkOracleSequence_UnknownOracle(address asset, address oracle) public {
        // Given a contract not added to the "OracleHub".
        vm.assume(oracle != address(mockOracles.token1ToUsd));
        vm.assume(oracle != address(mockOracles.token2ToUsd));
        vm.assume(oracle != address(mockOracles.stable1ToUsd));
        vm.assume(oracle != address(mockOracles.stable2ToUsd));
        vm.assume(oracle != address(mockOracles.nft1ToToken1));
        vm.assume(oracle != address(mockOracles.sft1ToToken1));
        address[] memory oracleTokenToUsdArr = new address[](1);
        oracleTokenToUsdArr[0] = oracle;

        vm.expectRevert("OH_COS: Oracle not active");
        oracleHub.checkOracleSequence(oracleTokenToUsdArr, asset);
    }

    function testFuzz_Revert_checkOracleSequence_InactiveOracle() public {
        vm.prank(users.creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation.
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );

        // And: The oracle is not active.
        vm.prank(users.defaultTransmitter);
        mockOracles.token4ToUsd.transmit(0); // Lower than min value
        oracleHub.decommissionOracle(address(mockOracles.token4ToUsd));

        // When "checkOracleSequence" is called.
        // Then: checkOracleSequence with oracleToken4ToUsdArr should revert with "OH_COS: Oracle not active".
        address[] memory oracleToken4ToUsdArr = new address[](1);
        oracleToken4ToUsdArr[0] = address(mockOracles.token4ToUsd);
        vm.expectRevert("OH_COS: Oracle not active");
        oracleHub.checkOracleSequence(oracleToken4ToUsdArr, address(mockERC20.token4));
    }

    function testFuzz_Revert_checkOracleSequence_NonMatchingFirstBaseAssets(address asset) public {
        vm.assume(asset != address(mockERC20.token4));

        // Given: creatorAddress addOracle with OracleInformation.
        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        // When: oracleToken4ToUsdArr index 0 is mockOracles.token4ToUsd.
        // Then: checkOracleSequence with oracleToken4ToUsdArr should revert with "OH_COS: No Match First bAsset" as asset != address(mockERC20.token4).
        address[] memory oracleToken4ToUsdArr = new address[](1);
        oracleToken4ToUsdArr[0] = address(mockOracles.token4ToUsd);
        vm.expectRevert("OH_COS: No Match First bAsset");
        oracleHub.checkOracleSequence(oracleToken4ToUsdArr, asset);
    }

    function testFuzz_Revert_checkOracleSequence_NonMatchingBaseAndQuoteAssets() public {
        vm.startPrank(users.creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation for TOKEN3-TOKEN4
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );
        vm.stopPrank();
        // When: oracleToken3ToUsdArr index 0 is mockOracles.token3ToToken4, oracleToken3ToUsdArr index 1 is mockOracles.token1ToUsd
        // Then: checkOracleSequence for oracleToken3ToUsdArr should revert with "OH_COS: No Match bAsset and qAsset"
        address[] memory oracleToken3ToUsdArr = new address[](2);
        oracleToken3ToUsdArr[0] = address(mockOracles.token3ToToken4);
        oracleToken3ToUsdArr[1] = address(mockOracles.token1ToUsd);
        vm.expectRevert("OH_COS: No Match bAsset and qAsset");
        oracleHub.checkOracleSequence(oracleToken3ToUsdArr, address(mockERC20.token3));
    }

    function testFuzz_Revert_checkOracleSequence_LastBaseAssetNotUsd() public {
        vm.startPrank(users.creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation for TOKEN3-TOKEN4
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );
        vm.stopPrank();
        // When: racleToken3ToUsdArr index 0 is mockOracles.token3ToToken4
        address[] memory oracleToken3ToUsdArr = new address[](1);
        oracleToken3ToUsdArr[0] = address(mockOracles.token3ToToken4);
        // Then: checkOracleSequence for oracleToken3ToUsdArr should revert with "OH_COS: Last qAsset not USD"
        vm.expectRevert("OH_COS: Last qAsset not USD");
        oracleHub.checkOracleSequence(oracleToken3ToUsdArr, address(mockERC20.token3));
    }

    function testFuzz_Success_checkOracleSequence_SingleOracleToUsd() public {
        vm.startPrank(users.creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();
        // When: oracleToken4ToUsdArr index 0 is mockOracles.token4ToUsd
        address[] memory oracleToken4ToUsdArr = new address[](1);
        oracleToken4ToUsdArr[0] = address(mockOracles.token4ToUsd);
        // Then: checkOracleSequence should pass for oracleToken4ToUsdArr
        oracleHub.checkOracleSequence(oracleToken4ToUsdArr, address(mockERC20.token4));
    }

    function testFuzz_Success_checkOracleSequence_MultipleOraclesToUsd() public {
        vm.startPrank(users.creatorAddress);
        // Given: creatorAddress addOracle for TOKEN3-TOKEN4 and TOKEN4-USD
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();
        // When: oracleToken3ToUsdArr index 0 is oracleToken3ToToken4, oracleToken3ToUsdArr index 1 is oracleToken4ToUsd,

        address[] memory oracleToken3ToUsdArr = new address[](2);
        oracleToken3ToUsdArr[0] = address(mockOracles.token3ToToken4);
        oracleToken3ToUsdArr[1] = address(mockOracles.token4ToUsd);
        // Then: checkOracleSequence should past for oracleToken3ToUsdArr
        oracleHub.checkOracleSequence(oracleToken3ToUsdArr, address(mockERC20.token3));
    }
}
