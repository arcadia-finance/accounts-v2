/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, StandardERC20PricingModule_Fuzz_Test } from "./_StandardERC20PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "_getAssetFromKey" of contract "StandardERC20PricingModule".
 */
contract GetAssetFromKey_StandardERC20PricingModule_Fuzz_Test is StandardERC20PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC20PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAssetFromKey(address asset, uint96 assetId) public {
        bytes32 key = bytes32(abi.encodePacked(assetId, asset));
        (address actualAsset, uint256 actualAssetId) = erc20PricingModule.getAssetFromKey(key);

        assertEq(actualAsset, asset);
        assertEq(actualAssetId, 0);
    }
}
