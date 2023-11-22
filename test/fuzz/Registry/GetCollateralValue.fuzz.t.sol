/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Registry_Fuzz_Test } from "./_Registry.fuzz.t.sol";

import { Constants } from "../../utils/Constants.sol";
import { AssetModule } from "../../../src/asset-modules/AbstractAssetModule.sol";
import { RiskModule } from "../../../src/RiskModule.sol";

/**
 * @notice Fuzz tests for the function "getCollateralValue" of contract "Registry".
 */
contract GetCollateralValue_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getCollateralValue_UnknownBaseCurrency(address baseCurrency) public {
        vm.assume(baseCurrency != address(0));
        vm.assume(!registryExtension.inRegistry(baseCurrency));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.stable2);
        assetAddresses[1] = address(mockERC721.nft1);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 10;
        assetAmounts[1] = 10;

        vm.expectRevert(bytes(""));
        registryExtension.getCollateralValue(baseCurrency, address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_getCollateralValue(int64 rateToken1ToUsd, uint64 amountToken1, uint16 collateralFactor_)
        public
    {
        vm.assume(collateralFactor_ <= RiskModule.RISK_FACTOR_UNIT);
        vm.assume(rateToken1ToUsd > 0);

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);

        uint256 token1ValueInUsd = convertAssetToUsd(Constants.tokenDecimals, amountToken1, oracleToken1ToUsdArr);
        vm.assume(token1ValueInUsd > 0);

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC20.token1), 0, type(uint128).max, collateralFactor_, 0
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountToken1;

        uint256 actualCollateralValue = registryExtension.getCollateralValue(
            address(0), address(creditorUsd), assetAddresses, assetIds, assetAmounts
        );

        uint256 expectedCollateralValue = token1ValueInUsd * collateralFactor_ / 10_000;

        assertEq(expectedCollateralValue, actualCollateralValue);
    }
}
