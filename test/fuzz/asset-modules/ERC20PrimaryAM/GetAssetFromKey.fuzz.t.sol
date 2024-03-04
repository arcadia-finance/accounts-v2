/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20PrimaryAM_Fuzz_Test } from "./_ERC20PrimaryAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getAssetFromKey" of contract "ERC20PrimaryAM".
 */
contract GetAssetFromKey_ERC20PrimaryAM_Fuzz_Test is ERC20PrimaryAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ERC20PrimaryAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAssetFromKey(address asset, uint96 assetId) public {
        bytes32 key = bytes32(abi.encodePacked(assetId, asset));
        (address actualAsset, uint256 actualAssetId) = erc20AssetModule.getAssetFromKey(key);

        assertEq(actualAsset, asset);
        assertEq(actualAssetId, 0);
    }
}
