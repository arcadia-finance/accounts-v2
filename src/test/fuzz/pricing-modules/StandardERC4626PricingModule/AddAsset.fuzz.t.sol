/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, StandardERC4626PricingModule_Fuzz_Test } from "./_StandardERC4626PricingModule.fuzz.t.sol";

import { ERC4626Mock } from "../../../../mockups/ERC4626Mock.sol";
import { PricingModule } from "../../../../pricing-modules/StandardERC20PricingModule.sol";

/**
 * @notice Fuzz tests for the "addAsset" of contract "StandardERC4626PricingModule".
 */
contract AddAsset_StandardERC4626PricingModule_Fuzz_Test is StandardERC4626PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_addAsset_NonOwner(address unprivilegedAddress_, address asset) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        erc4626PricingModule.addAsset(asset, emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_DecimalsDontMatch(uint8 decimals) public {
        vm.assume(decimals != mockERC20.token1.decimals());
        vm.assume(decimals <= 20);
        vm.prank(users.tokenCreatorAddress);
        ybToken1 = new ERC4626Mock(mockERC20.token1, "aETH Mock", "maETH", decimals);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PM4626_AA: Decimals don't match");
        erc4626PricingModule.addAsset(address(ybToken1), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(users.creatorAddress);
        erc4626PricingModule.addAsset(address(ybToken1), emptyRiskVarInput, type(uint128).max);
        vm.expectRevert("PM4626_AA: already added");
        erc4626PricingModule.addAsset(address(ybToken1), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        assertTrue(erc4626PricingModule.inPricingModule(address(ybToken1)));
    }

    function testSuccess_addAsset_EmptyListRiskVariables() public {
        vm.startPrank(users.creatorAddress);
        erc4626PricingModule.addAsset(address(ybToken1), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        assertTrue(erc4626PricingModule.inPricingModule(address(ybToken1)));
        assertEq(erc4626PricingModule.assetsInPricingModule(0), address(ybToken1));
        (uint64 assetUnit, address underlyingAsset, address[] memory oracles) =
            erc4626PricingModule.getAssetInformation(address(ybToken1));
        assertEq(assetUnit, 10 ** mockERC20.token1.decimals());
        assertEq(underlyingAsset, address(mockERC20.token1));
        for (uint256 i; i < oracleToken1ToUsdArr.length; ++i) {
            assertEq(oracles[i], oracleToken1ToUsdArr[i]);
        }
        assertTrue(erc4626PricingModule.isAllowListed(address(ybToken1), 0));
    }

    function testSuccess_addAsset_NonFullListRiskVariables() public {
        vm.startPrank(users.creatorAddress);
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });

        erc4626PricingModule.addAsset(address(ybToken1), riskVars_, type(uint128).max);
        vm.stopPrank();

        assertTrue(erc4626PricingModule.inPricingModule(address(ybToken1)));
    }
}
