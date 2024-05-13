/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import {
    AutoCompounder_Fuzz_Test,
    AutoCompounder,
    ERC20Mock,
    FixedPointMathLib,
    TickMath
} from "./_AutoCompounder.fuzz.t.sol";
import { ERC721 } from "../../../utils/mocks/tokens/ERC721Mock.sol";

/**
 * @notice Fuzz tests for the function "CompoundRewardsForAccount" of contract "AutoCompounder".
 */
contract CompoundRewardsForAccount_AutoCompounder_Fuzz_Test is AutoCompounder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AutoCompounder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_compoundRewardsForAccount(TestVariables memory testVars) public {
        // Given : Valid state
        bool token0HasLowestDecimals;
        (testVars, token0HasLowestDecimals) = givenValidBalancedState(testVars);

        // And : State is persisted
        uint256 tokenId = setState(testVars, usdStablePool);

        // And : Transfer position to account owner
        vm.prank(users.liquidityProvider);
        ERC721(address(nonfungiblePositionManager)).transferFrom(users.liquidityProvider, users.accountOwner, tokenId);

        // And : Deploy uniswapV3AM
        deployUniswapV3AM(address(nonfungiblePositionManager));

        {
            address[] memory assets_ = new address[](1);
            assets_[0] = address(nonfungiblePositionManager);
            uint256[] memory assetIds_ = new uint256[](1);
            assetIds_[0] = tokenId;
            uint256[] memory assetAmounts_ = new uint256[](1);
            assetAmounts_[0] = 1;

            // And : Deposit position in Account
            vm.startPrank(users.accountOwner);
            ERC721(address(nonfungiblePositionManager)).approve(address(proxyAccount), tokenId);
            proxyAccount.deposit(assets_, assetIds_, assetAmounts_);
            vm.stopPrank();
        }

        // And : AutoCompounder is allowed as Asset Manager
        vm.prank(users.accountOwner);
        proxyAccount.setAssetManager(address(autoCompounder), true);

        // When : Calling compoundRewardsForAccount()
        autoCompounder.compoundRewardsForAccount(address(proxyAccount), tokenId);
    }
}
