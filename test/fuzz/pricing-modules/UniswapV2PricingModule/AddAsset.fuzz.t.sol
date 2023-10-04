/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV2PricingModule_Fuzz_Test } from "./_UniswapV2PricingModule.fuzz.t.sol";
import { ArcadiaOracle } from "../../../utils/mocks/ArcadiaOracle.sol";
import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";
import { OracleHub } from "../../../../src/OracleHub.sol";

/**
 * @notice Fuzz tests for the "addAsset" of contract "UniswapV2PricingModule".
 */
contract AddAsset_UniswapV2PricingModule_Fuzz_Test is UniswapV2PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_Unauthorised(address unprivilegedAddress_) public {
        //Given: unprivilegedAddress_ is not protocol deployer
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        //When: unprivilegedAddress_ adds a new asset
        //Then: addAsset reverts with "UNAUTHORIZED"
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        uniswapV2PricingModule.addAsset(address(pairToken1Token2), emptyRiskVarInput);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_NonWhiteListedUnderlyingAsset() public {
        //Given: One of the underlying assets is not whitelisted
        //Given: We first need to add the asset to the pricing module in order to reach the require statement in "addAsset"
        ArcadiaOracle oracleToken3ToUsd =
            initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN3 / USD", uint256(1e18));
        address[] memory oracles = new address[](1);
        oracles[0] = address(oracleToken3ToUsd);

        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                baseAsset: "TOKEN3",
                quoteAsset: "USD",
                oracle: address(oracleToken3ToUsd),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );

        //Given: Asset is added with an exposure of 0
        erc20PricingModule.addAsset(address(mockERC20.token3), oracles, emptyRiskVarInput, 0);

        vm.expectRevert("PMUV2_AA: TOKENO_NOT_WHITELISTED");
        uniswapV2PricingModule.addAsset(address(pairToken1Token3), emptyRiskVarInput);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        //Given: asset is added to pricing module
        vm.prank(users.creatorAddress);
        uniswapV2PricingModule.addAsset(address(pairToken1Token2), emptyRiskVarInput);
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairToken1Token2)));

        //When: creator adds asset again
        vm.prank(users.creatorAddress);
        vm.expectRevert("PMUV2_AA: already added");
        uniswapV2PricingModule.addAsset(address(pairToken1Token2), emptyRiskVarInput);
    }

    function testFuzz_Success_addAsset_EmptyListCreditRatings() public {
        //Given: credit rating list is empty

        //When: creator adds a new asset
        vm.prank(users.creatorAddress);
        uniswapV2PricingModule.addAsset(address(pairToken1Token2), emptyRiskVarInput);

        //Then: Asset is added to the Pricing Module
        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairToken1Token2)));
        assertEq(uniswapV2PricingModule.assetsInPricingModule(0), address(pairToken1Token2));

        (,, address[] memory underlyingTokens,) = uniswapV2PricingModule.getAssetInformation(address(pairToken1Token2));

        assertEq(underlyingTokens[0], address(mockERC20.token2));
        assertEq(underlyingTokens[1], address(mockERC20.token1));
        assertTrue(uniswapV2PricingModule.isAllowListed(address(pairToken1Token2), 0));
    }

    function testFuzz_Success_addAsset_OwnerAddsAssetWithNonFullListRiskVariables() public {
        //Given: The number of credit ratings is not 0 and not the number of baseCurrencies
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });
        //When: creator adds a new asset
        //Then: addAsset reverts with "APM_SRV: LENGTH_MISMATCH"
        vm.startPrank(users.creatorAddress);
        uniswapV2PricingModule.addAsset(address(pairToken1Token2), riskVars_);
        vm.stopPrank();

        assertTrue(uniswapV2PricingModule.inPricingModule(address(pairToken1Token2)));
    }
}
