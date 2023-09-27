/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";
import { PricingModule_New } from "../../../../src/pricing-modules/AbstractPricingModule_New.sol";

/**
 * @notice Fuzz tests for the "addAsset" of contract "FloorERC721PricingModule".
 */
contract AddAsset_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();
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
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput_New, type(uint128).max
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        // Given:
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress addAsset twice
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput_New, type(uint128).max
        );
        vm.expectRevert("PM721_AA: already added");
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput_New, type(uint128).max
        );
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset_EmptyListRiskVariables() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset with empty list credit ratings
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput_New, type(uint128).max
        );
        vm.stopPrank();

        // Then: inPricingModule for address(mockERC721.nft2) should return true
        assertTrue(floorERC721PricingModule.inPricingModule(address(mockERC721.nft2)));
        assertEq(floorERC721PricingModule.assetsInPricingModule(1), address(mockERC721.nft2)); // Previously 1 asset was added in setup.
        (uint256 idRangeStart, uint256 idRangeEnd, address[] memory oracles) =
            floorERC721PricingModule.getAssetInformation(address(mockERC721.nft2));
        assertEq(idRangeStart, 0);
        assertEq(idRangeEnd, type(uint256).max);
        for (uint256 i; i < oracleNft2ToUsdArr.length; ++i) {
            assertEq(oracles[i], oracleNft2ToUsdArr[i]);
        }
        assertTrue(floorERC721PricingModule.isAllowListed(address(mockERC721.nft2), 0));
    }

    function testFuzz_Success_addAsset_NonFullListRiskVariables() public {
        vm.startPrank(users.creatorAddress);
        // Given: collateralFactors index 0 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 is DEFAULT_LIQUIDATION_FACTOR
        PricingModule_New.RiskVarInput[] memory riskVars_ = new PricingModule_New.RiskVarInput[](1);
        riskVars_[0] = PricingModule_New.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });
        // When: users.creatorAddress calls addAsset with wrong number of credits

        // Then: addAsset should add asset
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, riskVars_, type(uint128).max
        );
        vm.stopPrank();

        assertTrue(floorERC721PricingModule.inPricingModule(address(mockERC721.nft2)));
    }

    function testFuzz_Success_addAsset_FullListRiskVariables() public {
        PricingModule_New.RiskVarInput[] memory riskVars_ = new PricingModule_New.RiskVarInput[](3);
        riskVars_[0] = PricingModule_New.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });
        riskVars_[1] = PricingModule_New.RiskVarInput({
            baseCurrency: 1,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });
        riskVars_[2] = PricingModule_New.RiskVarInput({
            baseCurrency: 2,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });

        // Given: collateralFactors index 0 and 1 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 and 1 is DEFAULT_LIQUIDATION_FACTOR
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset with full list credit ratings
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, riskVars_, type(uint128).max
        );
        vm.stopPrank();

        // Then: inPricingModule for address(mockERC721.nft2) should return true
        assertTrue(floorERC721PricingModule.inPricingModule(address(mockERC721.nft2)));
    }
}
