/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC1155PricingModule_Fuzz_Test } from "./_FloorERC1155PricingModule.fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "FloorERC1155PricingModule".
 */
contract AddAsset_FloorERC1155PricingModule_Fuzz_Test is FloorERC1155PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not users.creatorAddress
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addAsset

        // Then: addAsset should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, emptyRiskVarInput);

        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_InvalidId(uint256 id) public {
        id = bound(id, uint256(type(uint96).max) + 1, type(uint256).max);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PM1155_AA: Invalid Id");
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), id, oracleSft2ToUsdArr, emptyRiskVarInput);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset twice
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, emptyRiskVarInput);
        vm.expectRevert("MR_AA: Asset already in mainreg");
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, emptyRiskVarInput);
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset_EmptyListRiskVariables() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset with empty list credit ratings
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, emptyRiskVarInput);
        vm.stopPrank();

        // Then: inPricingModule for address(mockERC1155.sft2) should return true
        assertTrue(floorERC1155PricingModule.inPricingModule(address(mockERC1155.sft2)));
        (uint256 id, address[] memory oracles) =
            floorERC1155PricingModule.getAssetInformation(address(mockERC1155.sft2));
        assertEq(id, 1);
        for (uint256 i; i < oracleSft2ToUsdArr.length; ++i) {
            assertEq(oracles[i], oracleSft2ToUsdArr[i]);
        }
        assertTrue(floorERC1155PricingModule.isAllowed(address(mockERC1155.sft2), 1));
    }

    function testFuzz_Success_addAsset_NonFullListRiskVariables() public {
        vm.startPrank(users.creatorAddress);
        // Given: collateralFactors index 0 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 is DEFAULT_LIQUIDATION_FACTOR
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });

        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, riskVars_);
        vm.stopPrank();

        assertTrue(floorERC1155PricingModule.inPricingModule(address(mockERC1155.sft2)));
    }

    function testFuzz_Success_addAsset_FullListRiskVariables() public {
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](3);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });
        riskVars_[1] = PricingModule.RiskVarInput({
            baseCurrency: 1,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });
        riskVars_[2] = PricingModule.RiskVarInput({
            baseCurrency: 2,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });

        // Given: collateralFactors index 0 and 1 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 and 1 is DEFAULT_LIQUIDATION_FACTOR
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset with full list credit ratings
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, riskVars_);
        vm.stopPrank();

        // Then: inPricingModule for address(mockERC1155.sft2) should return true
        assertTrue(floorERC1155PricingModule.inPricingModule(address(mockERC1155.sft2)));
    }
}
