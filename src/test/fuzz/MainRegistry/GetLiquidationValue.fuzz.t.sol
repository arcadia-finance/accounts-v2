/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

import { PricingModule } from "../../../pricing-modules/AbstractPricingModule.sol";
import { RiskConstants } from "../../../utils/RiskConstants.sol";
import { RiskModule } from "../../../RiskModule.sol";

/**
 * @notice Fuzz tests for the "getLiquidationValue" of contract "MainRegistry".
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
    function testRevert_Fuzz_getLiquidationValue_UnknownBaseCurrency(address basecurrency) public {
        vm.assume(basecurrency != address(0));
        vm.assume(basecurrency != address(mockERC20.stable1));
        vm.assume(basecurrency != address(mockERC20.token1));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token2);
        assetAddresses[1] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 1;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 1;

        vm.expectRevert("MR_GLV: UNKNOWN_BASECURRENCY");
        mainRegistryExtension.getLiquidationValue(assetAddresses, assetIds, assetAmounts, basecurrency);
    }

    function test_Fuzz_getLiquidationValue(int64 rateToken1ToUsd, uint64 amountToken1, uint16 liquidationFactor_)
        public
    {
        vm.assume(liquidationFactor_ <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        vm.assume(rateToken1ToUsd > 0);

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);

        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, amountToken1, oracleToken1ToUsdArr);
        vm.assume(token1ValueInUsd > 0);

        PricingModule.RiskVarInput[] memory riskVarsInput = new PricingModule.RiskVarInput[](1);
        riskVarsInput[0].asset = address(mockERC20.token1);
        riskVarsInput[0].baseCurrency = uint8(UsdBaseCurrencyID);
        riskVarsInput[0].liquidationFactor = liquidationFactor_;

        vm.startPrank(users.creatorAddress);
        erc20PricingModule.setBatchRiskVariables(riskVarsInput);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken1;

        uint256 actualLiquidationValue =
            mainRegistryExtension.getLiquidationValue(assetAddresses, assetIds, assetAmounts, address(0));

        uint256 expectedLiquidationValue = token1ValueInUsd * liquidationFactor_ / 100;

        assertEq(expectedLiquidationValue, actualLiquidationValue);
    }
}
