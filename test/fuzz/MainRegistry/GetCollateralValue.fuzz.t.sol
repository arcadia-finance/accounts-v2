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
 * @notice Fuzz tests for the function "getCollateralValue" of contract "MainRegistry".
 */
contract GetCollateralValue_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getCollateralValue_UnknownBaseCurrency(address basecurrency) public {
        vm.assume(basecurrency != address(0));
        vm.assume(basecurrency != address(mockERC20.stable1));
        vm.assume(basecurrency != address(mockERC20.token1));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.stable2);
        assetAddresses[1] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert("MR_GCV: UNKNOWN_BASECURRENCY");
        mainRegistryExtension.getCollateralValue(
            assetAddresses, assetIds, assetAmounts, basecurrency, address(creditorUsd)
        );
    }

    function testFuzz_Success_getCollateralValue(int64 rateToken1ToUsd, uint64 amountToken1, uint16 collateralFactor_)
        public
    {
        vm.assume(collateralFactor_ <= RiskConstants.RISK_FACTOR_UNIT);
        vm.assume(rateToken1ToUsd > 0);

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);

        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, amountToken1, oracleToken1ToUsdArr);
        vm.assume(token1ValueInUsd > 0);

        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC20.token1), 0, type(uint128).max, collateralFactor_, 0
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken1;

        uint256 actualCollateralValue = mainRegistryExtension.getCollateralValue(
            assetAddresses, assetIds, assetAmounts, address(0), address(creditorUsd)
        );

        uint256 expectedCollateralValue = token1ValueInUsd * collateralFactor_ / 100;

        assertEq(expectedCollateralValue, actualCollateralValue);
    }
}
