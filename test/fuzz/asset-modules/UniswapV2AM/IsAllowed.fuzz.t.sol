/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AM_Fuzz_Test } from "./_UniswapV2AM.fuzz.t.sol";

import { UniswapV2PairMalicious } from "../../../utils/mocks/UniswapV2/UniswapV2PairMalicious.sol";
import { UniswapV2PairMock } from "../../../utils/mocks/UniswapV2/UniswapV2PairMock.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "UniswapV2AM".
 */
contract IsAllowed_UniswapV2AM_Fuzz_Test is UniswapV2AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Negative_UnknownAsset(uint256 assetId) public {
        // Cannot fuzz asset, since calls to non-contracts are not caught by try/except and does revert.
        // Instead we fuzz to an existing contract without the correct interface.
        address asset = address(uniswapV2AM);

        assertFalse(uniswapV2AM.isAllowed(asset, assetId));
    }

    function testFuzz_Success_isAllowed_Negative_MaliciousPool(address token0, address token1, uint256 assetId)
        public
    {
        UniswapV2PairMalicious pool = new UniswapV2PairMalicious(token0, token1);

        assertFalse(uniswapV2AM.isAllowed(address(pool), assetId));
    }

    function testFuzz_Success_isAllowed_Negative_Token0NotAllowed(uint256 assetId) public {
        assertFalse(uniswapV2AM.isAllowed(address(pairToken1Token3), assetId));
    }

    function testFuzz_Success_isAllowed_Negative_Token1NotAllowed(uint256 assetId) public {
        UniswapV2PairMock pairToken1Token4 =
            UniswapV2PairMock(uniswapV2Factory.createPair(address(mockERC20.token1), address(mockERC20.token4)));

        assertFalse(uniswapV2AM.isAllowed(address(pairToken1Token4), assetId));
    }

    function testFuzz_Success_isAllowListed_Positive_UnderlyingAssetsAllowed(uint256 assetId) public {
        assertTrue(uniswapV2AM.isAllowed(address(pairToken1Token2), assetId));
    }

    function testFuzz_Success_isAllowListed_Positive_AssetInAssetModule(uint256 assetId) public {
        uniswapV2AM.addAsset(address(pairToken1Token2));

        assertTrue(uniswapV2AM.isAllowed(address(pairToken1Token2), assetId));
    }
}
