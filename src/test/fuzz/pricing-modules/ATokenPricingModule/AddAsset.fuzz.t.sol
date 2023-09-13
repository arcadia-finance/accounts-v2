/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, ATokenPricingModule_Fuzz_Test } from "./ATokenPricingModule.fuzz.t.sol";

import { ATokenMock } from "../../../../mockups/ATokenMock.sol";
import { PricingModule } from "../../../../pricing-modules/ATokenPricingModule.sol";

/**
 * @notice Fuzz tests for the "addAsset" of contract "ATokenPricingModule".
 */
contract AddAsset_ATokenPricingModule_Fuzz_Test is ATokenPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ATokenPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_addAsset_NonOwner(address unprivilegedAddress_, address asset) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        aTokenPricingModule.addAsset(asset, emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_DecimalsDontMatch(uint8 decimals) public {
        vm.assume(decimals != mockERC20.token1.decimals());
        vm.assume(decimals <= 20);
        vm.prank(users.tokenCreatorAddress);
        aToken2 = new ATokenMock(address(mockERC20.token1), "aETH Mock", "maETH", decimals);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PMAT_AA: Decimals don't match");
        aTokenPricingModule.addAsset(address(aToken2), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(users.creatorAddress);
        aTokenPricingModule.addAsset(address(aToken2), emptyRiskVarInput, type(uint128).max);
        vm.expectRevert("PMAT_AA: already added");
        aTokenPricingModule.addAsset(address(aToken2), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aToken2)));
    }

    function testSuccess_addAsset_EmptyListRiskVariables() public {
        vm.prank(users.creatorAddress);
        aTokenPricingModule.addAsset(address(aToken2), emptyRiskVarInput, type(uint128).max);

        assertTrue(aTokenPricingModule.inPricingModule(address(aToken2)));
        assertEq(aTokenPricingModule.assetsInPricingModule(1), address(aToken2)); // Previously 1 asset was added in setup.
        (uint64 assetUnit, address underlyingAsset, address[] memory oracles) =
            aTokenPricingModule.getAssetInformation(address(aToken2));
        assertEq(assetUnit, 10 ** mockERC20.token2.decimals());
        assertEq(underlyingAsset, address(mockERC20.token2));
        for (uint256 i; i < oracleToken2ToUsdArr.length; ++i) {
            assertEq(oracles[i], oracleToken2ToUsdArr[i]);
        }
        assertTrue(aTokenPricingModule.isAllowListed(address(aToken2), 0));
    }

    function testSuccess_addAsset_NonFullListRiskVariables() public {
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });

        vm.prank(users.creatorAddress);
        aTokenPricingModule.addAsset(address(aToken2), riskVars_, type(uint128).max);

        assertTrue(aTokenPricingModule.inPricingModule(address(aToken2)));
    }
}
