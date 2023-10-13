/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, ATokenPricingModule_Fuzz_Test } from "./_ATokenPricingModule.fuzz.t.sol";

import { ATokenMock } from "../../.././utils/mocks/ATokenMock.sol";
import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";

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
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_, address asset) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        aTokenPricingModule.addAsset(asset, emptyRiskVarInput);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_DecimalsDontMatch(uint8 decimals) public {
        vm.assume(decimals != mockERC20.token1.decimals());
        vm.assume(decimals <= 20);
        vm.prank(users.tokenCreatorAddress);
        aToken1 = new ATokenMock(address(mockERC20.token1), "aETH Mock", "maETH", decimals);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PMAT_AA: Decimals don't match");
        aTokenPricingModule.addAsset(address(aToken1), emptyRiskVarInput);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(users.creatorAddress);
        aTokenPricingModule.addAsset(address(aToken1), emptyRiskVarInput);
        vm.expectRevert("PMAT_AA: already added");
        aTokenPricingModule.addAsset(address(aToken1), emptyRiskVarInput);
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aToken1)));
    }

    function testFuzz_Success_addAsset_EmptyListRiskVariables() public {
        vm.startPrank(users.creatorAddress);
        aTokenPricingModule.addAsset(address(aToken1), emptyRiskVarInput);
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aToken1)));
        assertEq(aTokenPricingModule.assetsInPricingModule(0), address(aToken1));

        (uint64 assetUnit) = aTokenPricingModule.aTokenAssetToInformation(address(aToken1));
        assertEq(assetUnit, 10 ** mockERC20.token1.decimals());

        assertTrue(aTokenPricingModule.isAllowed(address(aToken1), 0));

        // We ensure that the correct oracle from the underlying asset was added in
        // ATokenAssetInformation through our testing of GetValue().
    }

    function testFuzz_Success_addAsset_NonFullListRiskVariables() public {
        vm.startPrank(users.creatorAddress);
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });

        aTokenPricingModule.addAsset(address(aToken1), riskVars_);
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aToken1)));
    }
}
