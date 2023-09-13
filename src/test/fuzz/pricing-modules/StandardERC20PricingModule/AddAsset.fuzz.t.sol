/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, StandardERC20PricingModule_Fuzz_Test } from "./StandardERC20PricingModule.fuzz.t.sol";

import { OracleHub } from "../../../../OracleHub.sol";
import { PricingModule, StandardERC20PricingModule } from "../../../../pricing-modules/StandardERC20PricingModule.sol";
import { ERC20Mock } from "../../../../mockups/ERC20SolmateMock.sol";
import { ArcadiaOracle } from "../../../../mockups/ArcadiaOracle.sol";

/**
 * @notice Fuzz tests for the "addAsset" of contract "StandardERC20PricingModule".
 */
contract AddAsset_StandardERC20PricingModule_Fuzz_Test is StandardERC20PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC20PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_addAsset_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not users.creatorAddress
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addAsset

        // Then: addAsset should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        erc20PricingModule.addAsset(
            address(mockERC20.token4), oracleToken4ToUsdArr, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();
    }

    function testRevert_addAsset_OverwriteExistingAsset() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset twice
        erc20PricingModule.addAsset(
            address(mockERC20.token4), oracleToken4ToUsdArr, emptyRiskVarInput, type(uint128).max
        );
        vm.expectRevert("PM20_AA: already added");
        erc20PricingModule.addAsset(
            address(mockERC20.token4), oracleToken4ToUsdArr, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();
    }

    function testRevert_addAsset_BadOracleSequence() public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("OH_COS: Min 1 Oracle");
        erc20PricingModule.addAsset(address(mockERC20.token4), new address[](0), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_MoreThan18Decimals() public {
        vm.prank(users.tokenCreatorAddress);
        ERC20Mock asset = new ERC20Mock("ASSET", "ASSET", 19);
        ArcadiaOracle oracle = initMockedOracle(0, "ASSET / USD");
        address[] memory oracleAssetToUsdArr = new address[](1);
        oracleAssetToUsdArr[0] = address(oracle);
        vm.prank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: 0,
                baseAsset: "ASSET",
                quoteAsset: "USD",
                oracle: address(oracle),
                baseAssetAddress: address(asset),
                isActive: true
            })
        );

        // When: users.creatorAddress calls addAsset with 19 decimals
        // Then: addAsset should revert with "PM20_AA: Maximal 18 decimals"
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PM20_AA: Maximal 18 decimals");
        erc20PricingModule.addAsset(address(asset), oracleAssetToUsdArr, emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    function testSuccess_addAsset_EmptyListRiskVariables() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset with empty list credit ratings
        vm.expectEmit(true, true, true, true);
        emit MaxExposureSet(address(mockERC20.token4), type(uint128).max);
        erc20PricingModule.addAsset(
            address(mockERC20.token4), oracleToken4ToUsdArr, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        // Then: address(mockERC20.token4) should be inPricingModule
        assertTrue(erc20PricingModule.inPricingModule(address(mockERC20.token4)));
        assertEq(erc20PricingModule.assetsInPricingModule(4), address(mockERC20.token4)); // Previously 4 assets were added in setup.
        (uint64 assetUnit, address[] memory oracles) = erc20PricingModule.getAssetInformation(address(mockERC20.token4));
        assertEq(assetUnit, 10 ** uint8(Constants.tokenDecimals));
        for (uint256 i; i < oracleToken4ToUsdArr.length; ++i) {
            assertEq(oracles[i], oracleToken4ToUsdArr[i]);
        }
        assertTrue(erc20PricingModule.isAllowListed(address(mockERC20.token4), 0));
    }

    function testSuccess_addAsset_NonFullListRiskVariables() public {
        // Given: collateralFactors index 0 is DEFAULT_COLLATERAL_FACTOR, liquidationThresholds index 0 is DEFAULT_LIQUIDATION_FACTOR
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });
        // When: users.creatorAddress calls addAsset with wrong number of credits

        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskVariablesSet(address(mockERC20.token4), 0, collateralFactor, liquidationFactor);
        vm.expectEmit(true, true, true, true);
        emit MaxExposureSet(address(mockERC20.token4), type(uint128).max);
        erc20PricingModule.addAsset(address(mockERC20.token4), oracleToken4ToUsdArr, riskVars_, type(uint128).max);
        vm.stopPrank();

        // Then: addAsset should add asset
        assertTrue(erc20PricingModule.inPricingModule(address(mockERC20.token4)));
    }

    function testSuccess_addAsset_FullListRiskVariables() public {
        // Given:
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

        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset with full list credit ratings
        erc20PricingModule.addAsset(address(mockERC20.token4), oracleToken4ToUsdArr, riskVars_, type(uint128).max);
        vm.stopPrank();

        // Then: address(mockERC20.token4) should be inPricingModule
        assertTrue(erc20PricingModule.inPricingModule(address(mockERC20.token4)));
    }
}
