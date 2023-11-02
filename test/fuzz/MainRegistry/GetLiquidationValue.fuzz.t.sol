/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

import { Constants } from "../../utils/Constants.sol";
import { PricingModule } from "../../../src/pricing-modules/AbstractPricingModule.sol";
import { RiskConstants } from "../../../src/libraries/RiskConstants.sol";
import { RiskModule } from "../../../src/RiskModule.sol";

/**
 * @notice Fuzz tests for the function "getLiquidationValue" of contract "MainRegistry".
 */
contract GetLiquidationValue_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getLiquidationValue_UnknownBaseCurrency(address baseCurrency) public {
        vm.assume(baseCurrency != address(0));
        vm.assume(!mainRegistryExtension.inMainRegistry(baseCurrency));

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
        mainRegistryExtension.getLiquidationValue(
            baseCurrency, address(creditorUsd), assetAddresses, assetIds, assetAmounts
        );
    }

    function testFuzz_Success_getLiquidationValue(int64 rateToken1ToUsd, uint64 amountToken1, uint16 liquidationFactor_)
        public
    {
        vm.assume(liquidationFactor_ <= RiskConstants.RISK_FACTOR_UNIT);
        vm.assume(rateToken1ToUsd > 0);

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);

        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, amountToken1, oracleToken1ToUsdArr);
        vm.assume(token1ValueInUsd > 0);

        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC20.token1), 0, type(uint128).max, 0, liquidationFactor_
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken1;

        uint256 actualLiquidationValue = mainRegistryExtension.getLiquidationValue(
            address(0), address(creditorUsd), assetAddresses, assetIds, assetAmounts
        );

        uint256 expectedLiquidationValue = token1ValueInUsd * liquidationFactor_ / 100;

        assertEq(expectedLiquidationValue, actualLiquidationValue);
    }
}
