/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryL1_Fuzz_Test } from "./_RegistryL1.fuzz.t.sol";

import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { Constants } from "../../../utils/Constants.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";

/**
 * @notice Fuzz tests for the function "getTotalValue" of contract "RegistryL1".
 */
/// forge-lint: disable-next-item(divide-before-multiply)
contract GetTotalValue_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_getTotalValue_UnknownNumeraire(address numeraire) public {
        vm.assume(numeraire != address(0));
        vm.assume(!registry_.inRegistry(numeraire));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.stable2);
        assetAddresses[1] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert(abi.encodePacked("call to non-contract address ", vm.toString(address(0))));
        registry_.getTotalValue(numeraire, address(creditorToken1), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Revert_getTotalValue_CalculateValueInNumeraireFromValueInUsdOverflow(
        uint256 rateToken1ToUsd,
        uint256 amountToken2,
        uint8 token2Decimals
    ) public {
        vm.assume(token2Decimals < Constants.TOKEN_ORACLE_DECIMALS);
        vm.assume(rateToken1ToUsd <= uint256(type(int256).max));
        vm.assume(rateToken1ToUsd > 0);
        vm.assume(
            amountToken2
                > ((type(uint256).max / uint256(rates.token2ToUsd) / Constants.WAD) * 10 ** Constants.TOKEN_ORACLE_DECIMALS)
                    / 10 ** (Constants.TOKEN_ORACLE_DECIMALS - token2Decimals)
        );

        ArcadiaOracle oracle = initMockedOracle(uint8(0), "LINK / USD", int256(0));
        vm.startPrank(users.owner);
        mockERC20.token2 = new ERC20Mock("TOKEN2", "T2", token2Decimals);

        uint80 oracleId = uint80(chainlinkOM.addOracle(address(oracle), "TOKEN2", "USD", 2 days));
        uint80[] memory oracleAssetToUsdArr = new uint80[](1);
        oracleAssetToUsdArr[0] = oracleId;

        erc20AM.addAsset(address(mockERC20.token2), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAssetToUsdArr));
        vm.stopPrank();
        vm.prank(users.riskManager);
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC20.token2), 0, type(uint112).max, 0, 0
        );

        vm.startPrank(users.transmitter);
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
        registry_.getTotalValue(
            address(mockERC20.token1), address(creditorToken1), assetAddresses, assetIds, assetAmounts
        );
    }

    function testFuzz_Revert_getTotalValue_CalculateValueInNumeraireFromValueInUsdWithRateZero(uint256 amountToken2)
        public
    {
        vm.assume(amountToken2 > 0);

        vm.startPrank(users.transmitter);
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
        registry_.getTotalValue(
            address(mockERC20.token1), address(creditorToken1), assetAddresses, assetIds, assetAmounts
        );
    }

    function testFuzz_Success_getTotalValue(uint32 currentTime) public {
        // Given: oracle staleness-check does not underflow.
        currentTime = uint32(bound(currentTime, 2 days, type(uint32).max));
        vm.warp(currentTime);

        // And: Oracles are not stale.
        vm.startPrank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd));
        mockOracles.token2ToUsd.transmit(int256(rates.token2ToUsd));
        mockOracles.nft1ToToken1.transmit(int256(rates.nft1ToToken1));
        vm.stopPrank();

        // And: Risk parameters are set.
        vm.prank(creditorToken1.riskManager());
        registry_.setRiskParameters(address(creditorToken1), 0, type(uint64).max);

        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.token2);
        assetAddresses[2] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](3);
        assetIds[0] = 0;
        assetIds[1] = 0;
        assetIds[2] = 1;

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 10 ** Constants.TOKEN_DECIMALS;
        assetAmounts[1] = 10 ** Constants.TOKEN_DECIMALS;
        assetAmounts[2] = 1;

        // Numeraire for actualTotalValue is set to mockERC20.token1
        uint256 actualTotalValue = registry_.getTotalValue(
            address(mockERC20.token1), address(creditorToken1), assetAddresses, assetIds, assetAmounts
        );

        uint256 token1ValueInToken1 = assetAmounts[0];
        uint256 token2ValueInToken1 = convertUsdToNumeraire(
            Constants.TOKEN_DECIMALS,
            convertAssetToUsd(Constants.TOKEN_DECIMALS, assetAmounts[1], oracleToken2ToUsdArr),
            rates.token1ToUsd,
            Constants.TOKEN_ORACLE_DECIMALS
        );
        uint256 nft1ValueInToken1 = convertUsdToNumeraire(
            Constants.TOKEN_DECIMALS,
            convertAssetToUsd(0, assetAmounts[2], oracleNft1ToToken1ToUsd),
            rates.token1ToUsd,
            Constants.TOKEN_ORACLE_DECIMALS
        );

        uint256 expectedTotalValue = token1ValueInToken1 + token2ValueInToken1 + nft1ValueInToken1;

        assertEq(expectedTotalValue, actualTotalValue);
    }

    function testFuzz_Success_getTotalValue_CalculateValueInNumeraireFromValueInUsd_token2With18Decimals(
        uint256 rateToken1ToUsd,
        uint256 amountToken2
    ) public {
        rateToken1ToUsd = bound(rateToken1ToUsd, 1, type(uint256).max / 10 ** (36 - Constants.TOKEN_ORACLE_DECIMALS));

        vm.assume(
            amountToken2
                <= type(uint256).max / uint256(rates.token2ToUsd) / Constants.WAD
                    / 10 ** (Constants.TOKEN_ORACLE_DECIMALS - Constants.TOKEN_ORACLE_DECIMALS)
        );
        vm.assume(
            amountToken2
                <= (
                    (
                        (type(uint256).max / uint256(rates.token2ToUsd) / Constants.WAD)
                            * 10 ** Constants.TOKEN_ORACLE_DECIMALS
                    ) / 10 ** Constants.TOKEN_ORACLE_DECIMALS
                ) * 10 ** Constants.TOKEN_DECIMALS
        );

        vm.startPrank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        uint256 actualTotalValue = registry_.getTotalValue(
            address(mockERC20.token1), address(creditorToken1), assetAddresses, assetIds, assetAmounts
        );

        uint256 token2ValueInUsd = convertAssetToUsd(Constants.TOKEN_DECIMALS, amountToken2, oracleToken2ToUsdArr);
        uint256 token2ValueInToken1 = convertUsdToNumeraire(
            Constants.TOKEN_DECIMALS, token2ValueInUsd, rateToken1ToUsd, Constants.TOKEN_ORACLE_DECIMALS
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
        rateToken1ToUsd = bound(rateToken1ToUsd, 1, type(uint256).max / 10 ** (36 - Constants.TOKEN_ORACLE_DECIMALS));

        vm.startPrank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd));
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.stable2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken2;

        uint256 actualTotalValue = registry_.getTotalValue(
            address(mockERC20.token1), address(creditorToken1), assetAddresses, assetIds, assetAmounts
        );

        uint256 token2ValueInUsd = convertAssetToUsd(Constants.STABLE_DECIMALS, amountToken2, oracleStable2ToUsdArr);
        uint256 token2ValueInToken1 = convertUsdToNumeraire(
            Constants.TOKEN_DECIMALS, token2ValueInUsd, rateToken1ToUsd, Constants.TOKEN_ORACLE_DECIMALS
        );

        uint256 expectedValue = token2ValueInToken1;

        // Then: expectedTotalValue should be equal to actualTotalValue
        assertEq(expectedValue, actualTotalValue);
    }
}
