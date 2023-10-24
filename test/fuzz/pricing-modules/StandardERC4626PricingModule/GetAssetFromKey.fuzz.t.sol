/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { StandardERC4626PricingModule_Fuzz_Test } from "./_StandardERC4626PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getAssetFromKey" of contract "StandardERC4626PricingModule".
 */
contract GetAssetFromKey_StandardERC4626PricingModule_Fuzz_Test is StandardERC4626PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAssetFromKey(address asset, uint96 assetId) public {
        bytes32 key = bytes32(abi.encodePacked(assetId, asset));
        (address actualAsset, uint256 actualAssetId) = erc4626PricingModule.getAssetFromKey(key);

        assertEq(actualAsset, asset);
        assertEq(actualAssetId, 0);
    }
}
