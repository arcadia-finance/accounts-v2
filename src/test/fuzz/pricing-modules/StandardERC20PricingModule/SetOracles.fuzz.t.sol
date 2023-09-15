/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, StandardERC20PricingModule_Fuzz_Test } from "./_StandardERC20PricingModule.fuzz.t.sol";

import { OracleHub } from "../../../../OracleHub.sol";
import { StandardERC20PricingModule } from "../../../../pricing-modules/StandardERC20PricingModule.sol";
import { ArcadiaOracle } from "../../../../mockups/ArcadiaOracle.sol";

/**
 * @notice Fuzz tests for the "setOracles" of contract "StandardERC20PricingModule".
 */
contract SetOracles_StandardERC20PricingModule_Fuzz_Test is StandardERC20PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC20PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_setOracles_NonOwner(address asset, address oracle, address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        erc20PricingModule.setOracles(asset, oracleToken4ToUsdArr, oracle);
        vm.stopPrank();
    }

    function testFuzz_Revert_setOracles_UnknownAsset(address asset, address oracle) public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PM20_SO: Unknown Oracle");
        erc20PricingModule.setOracles(asset, new address[](0), oracle);
        vm.stopPrank();
    }

    function testFuzz_Revert_setOracles_UnknownOracle(address oracle) public {
        vm.assume(oracle != address(mockOracles.token4ToUsd));

        vm.prank(users.creatorAddress);
        erc20PricingModule.addAsset(
            address(mockERC20.token4), oracleToken4ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PM20_SO: Unknown Oracle");
        erc20PricingModule.setOracles(address(mockERC20.token4), oracleToken4ToUsdArr, oracle);
        vm.stopPrank();
    }

    function testFuzz_Revert_setOracles_ActiveOracle() public {
        vm.prank(users.creatorAddress);
        erc20PricingModule.addAsset(
            address(mockERC20.token4), oracleToken4ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PM20_SO: Oracle still active");
        erc20PricingModule.setOracles(address(mockERC20.token4), oracleToken4ToUsdArr, address(mockOracles.token4ToUsd));
        vm.stopPrank();
    }

    function testFuzz_Revert_setOracles_BadOracleSequence() public {
        vm.prank(users.creatorAddress);
        erc20PricingModule.addAsset(
            address(mockERC20.token4), oracleToken4ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.prank(users.defaultTransmitter);
        mockOracles.token4ToUsd.transmit(0);
        oracleHub.decommissionOracle(address(mockOracles.token4ToUsd));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("OH_COS: Oracle not active");
        erc20PricingModule.setOracles(address(mockERC20.token4), oracleToken4ToUsdArr, address(mockOracles.token4ToUsd));
        vm.stopPrank();
    }

    function testFuzz_Success_setOracles() public {
        vm.prank(users.creatorAddress);
        erc20PricingModule.addAsset(
            address(mockERC20.token4), oracleToken4ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.prank(users.defaultTransmitter);
        mockOracles.token4ToUsd.transmit(0);
        oracleHub.decommissionOracle(address(mockOracles.token4ToUsd));

        ArcadiaOracle oracle = initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN4 / USD", rates.token4ToUsd);
        vm.startPrank(users.creatorAddress);
        address[] memory oracleAssetToUsdArr = new address[](1);
        oracleAssetToUsdArr[0] = address(oracle);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                baseAsset: "ETH",
                quoteAsset: "USD",
                oracle: address(oracle),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        vm.startPrank(users.creatorAddress);
        erc20PricingModule.setOracles(address(mockERC20.token4), oracleAssetToUsdArr, address(mockOracles.token4ToUsd));
    }
}
