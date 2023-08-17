/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test, Constants } from "../Base_IntegrationAndUnit.t.sol";
import { OracleHub_UsdOnly } from "../../OracleHub_UsdOnly.sol";

contract OracleHub_Unit_Test is Base_IntegrationAndUnit_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                          ORACLE MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_addOracle_Owner(uint64 oracleToken4ToUsdUnit) public {
        // Given: oracleToken4ToUsdUnit is less than equal to 1 ether
        vm.assume(oracleToken4ToUsdUnit <= 10 ** 18);
        // When: creatorAddress addOracle with OracleInformation
        vm.startPrank(users.creatorAddress);
        vm.expectEmit();
        emit OracleAdded(address(mockOracles.token4ToUsd), address(mockERC20.token4), "USD");
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: oracleToken4ToUsdUnit,
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        // Then: oracleToken4ToUsd should return true to inOracleHub
        assertTrue(oracleHub.inOracleHub(address(mockOracles.token4ToUsd)));
        (
            bool isActive,
            uint64 oracleUnit,
            ,
            address baseAssetAddress,
            bytes16 baseAsset,
            bytes16 quoteAsset
        ) = oracleHub.oracleToOracleInformation(address(mockOracles.token4ToUsd));
        assertEq(oracleUnit, oracleToken4ToUsdUnit);
        assertEq(baseAsset, "TOKEN4");
        assertEq(quoteAsset, "USD");
        assertEq(baseAssetAddress, address(mockERC20.token4));
        assertEq(isActive, true);
    }

    function testRevert_addOracle_OverwriteOracle() public {
        vm.startPrank(users.creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        // When: creatorAddress addOracle

        // Then: addOracle should revert with "OH_AO: Oracle not unique"
        vm.expectRevert("OH_AO: Oracle not unique");
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();
    }

    function testRevert_addOracle_NonOwner(address unprivilegedAddress) public {
        // Given: unprivilegedAddress is not creatorAddress
        vm.assume(unprivilegedAddress != users.creatorAddress);
        // When: unprivilegedAddress addOracle
        vm.startPrank(users.unprivilegedAddress);
        // Then: addOracle should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();
    }

    function testRevert_addOracle_BigOracleUnit(uint64 oracleEthToUsdUnit) public {
        // Given: oracleEthToUsdUnit is bigger than 1 ether
        vm.assume(oracleEthToUsdUnit > 10 ** 18);
        // When: creatorAddress addOracle
        vm.startPrank(users.creatorAddress);
        // Then: addOracle should revert with "OH_AO: Maximal 18 decimals"
        vm.expectRevert("OH_AO: Maximal 18 decimals");
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();
    }

    function test_checkOracleSequence_SingleOracleToUsd() public {
        vm.startPrank(users.creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
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

    function test_checkOracleSequence_MultipleOraclesToUsd() public {
        vm.startPrank(users.creatorAddress);
        // Given: creatorAddress addOracle for TOKEN3-TOKEN4 and TOKEN4-USD
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
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

    function testFuzz_Revert_checkOracleSequence_NonMatchingFirstQuoteAssets(address asset) public {
        vm.assume(asset != address(mockERC20.token4));
        vm.startPrank(users.creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
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

        // Then: checkOracleSequence with oracleToken4ToUsdArr should revert with "OH_COS: No Match First bAsset" as asset != address(mockERC20.token4)
        vm.expectRevert("OH_COS: No Match First bAsset");
        oracleHub.checkOracleSequence(oracleToken4ToUsdArr, asset);
    }
}