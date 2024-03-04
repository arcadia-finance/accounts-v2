/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AM_Fuzz_Test } from "./_UniswapV2AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getAssetFromKey" of contract "UniswapV2AM".
 */
contract GetAssetFromKey_UniswapV2AM_Fuzz_Test is UniswapV2AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAssetFromKey(address asset, uint96 assetId) public {
        bytes32 key = bytes32(abi.encodePacked(assetId, asset));
        (address actualAsset, uint256 actualAssetId) = uniswapV2AM.getAssetFromKey(key);

        assertEq(actualAsset, asset);
        assertEq(actualAssetId, 0);
    }
}
