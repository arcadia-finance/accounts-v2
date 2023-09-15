/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, OracleHub_Fuzz_Test } from "./_OracleHub.fuzz.t.sol";

import { OracleHub } from "../../../OracleHub.sol";

/**
 * @notice Fuzz tests for the function "addOracle" of contract "OracleHub".
 */
contract AddOracle_OracleHub_Fuzz_Test is OracleHub_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        OracleHub_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testRevert_Fuzz_addOracle_NonOwner(address unprivilegedAddress) public {
        // Given: unprivilegedAddress is not creatorAddress.
        vm.assume(unprivilegedAddress != users.creatorAddress);

        // When: unprivilegedAddress addOracle.
        // Then: addOracle reverts with "UNAUTHORIZED".
        vm.startPrank(users.unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
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
    }

    function testRevert_addOracle_OverwriteOracle() public {
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

        // When: creatorAddress adds oracle a second time.
        // Then: addOracle reverts with "OH_AO: Oracle not unique".
        vm.expectRevert("OH_AO: Oracle not unique");
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
    }

    function testRevert_Fuzz_addOracle_BigOracleUnit(uint64 oracleEthToUsdUnit) public {
        // Given: oracleEthToUsdUnit is bigger than 1 ether.
        vm.assume(oracleEthToUsdUnit > 10 ** 18);

        // When: creatorAddress addOracle.
        // Then: addOracle should revert with "OH_AO: Maximal 18 decimals".
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("OH_AO: Maximal 18 decimals");
        oracleHub.addOracle(
            OracleHub.OracleInformation({
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

    function testFuzz_Pass_addOracle(uint64 oracleToken4ToUsdUnit) public {
        // Given: oracleToken4ToUsdUnit is less than equal to 1 ether.
        vm.assume(oracleToken4ToUsdUnit <= 10 ** 18);

        // When: creatorAddress addOracle with OracleInformation.
        vm.startPrank(users.creatorAddress);
        vm.expectEmit();
        emit OracleAdded(address(mockOracles.token4ToUsd), address(mockERC20.token4), "USD");
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: oracleToken4ToUsdUnit,
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        // Then: oracleToken4ToUsd should return true to inOracleHub.
        assertTrue(oracleHub.inOracleHub(address(mockOracles.token4ToUsd)));
        (bool isActive, uint64 oracleUnit,, address baseAssetAddress, bytes16 baseAsset, bytes16 quoteAsset) =
            oracleHub.oracleToOracleInformation(address(mockOracles.token4ToUsd));
        assertEq(oracleUnit, oracleToken4ToUsdUnit);
        assertEq(baseAsset, "TOKEN4");
        assertEq(quoteAsset, "USD");
        assertEq(baseAssetAddress, address(mockERC20.token4));
        assertEq(isActive, true);
    }
}
