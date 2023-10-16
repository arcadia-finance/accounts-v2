/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV2PricingModule_Fuzz_Test } from "./_UniswapV2PricingModule.fuzz.t.sol";

import { UniswapV2PairMalicious } from "../../../utils/mocks/UniswapV2PairMalicious.sol";
import { UniswapV2PairMock } from "../../.././utils/mocks/UniswapV2PairMock.sol";

/**
 * @notice Fuzz tests for the "isAllowed" of contract "UniswapV2PricingModule".
 */
contract IsAllowed_UniswapV2PricingModule_Fuzz_Test is UniswapV2PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Negative_UnknownAsset(uint256 assetId) public {
        // Cannot fuzz asset, since calls to non-contracts are not caught by try/except and does revert.
        // Instead we fuzz to an existing contract without the correct interface.
        address asset = address(uniswapV2PricingModule);

        assertFalse(uniswapV2PricingModule.isAllowed(asset, assetId));
    }

    function testFuzz_Success_isAllowed_Negative_MaliciousPool(address token0, address token1, uint256 assetId)
        public
    {
        UniswapV2PairMalicious pool = new UniswapV2PairMalicious(token0, token1);

        assertFalse(uniswapV2PricingModule.isAllowed(address(pool), assetId));
    }

    function testFuzz_Success_isAllowed_Negative_Token0NotAllowed(uint256 assetId) public {
        assertFalse(uniswapV2PricingModule.isAllowed(address(pairToken1Token3), assetId));
    }

    function testFuzz_Success_isAllowed_Negative_Token1NotAllowed(uint256 assetId) public {
        UniswapV2PairMock pairToken1Token4 =
            UniswapV2PairMock(uniswapV2Factory.createPair(address(mockERC20.token1), address(mockERC20.token4)));

        assertFalse(uniswapV2PricingModule.isAllowed(address(pairToken1Token4), assetId));
    }

    function testFuzz_Success_isAllowListed_Positive_UnderlyingAssetsAllowed(uint256 assetId) public {
        assertTrue(uniswapV2PricingModule.isAllowed(address(pairToken1Token2), assetId));
    }

    function testFuzz_Success_isAllowListed_Positive_AssetInPricingModule(uint256 assetId) public {
        uniswapV2PricingModule.addPool(address(pairToken1Token2));

        assertTrue(uniswapV2PricingModule.isAllowed(address(pairToken1Token2), assetId));
    }
}
