/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractAM_Fuzz_Test } from "./_AbstractAM.fuzz.t.sol";

import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { AssetModuleMock } from "../../../utils/mocks/asset-modules/AssetModuleMock.sol";

/**
 * @notice Fuzz tests for the function "processAsset" of contract "AbstractAssetModule".
 */
contract ProcessAsset_AbstractAM_Fuzz_Test is AbstractAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processAsset_NotAllowed(uint256 assetType, address asset, uint96 assetId) public {
        AssetModuleMock assetModule_ = new AssetModuleMock(address(registryExtension), assetType);

        assetModule_.setIsAllowedResponse(false);

        (bool isAllowed, uint256 assetType_) = assetModule_.processAsset(asset, assetId);
        assertFalse(isAllowed);
        assertEq(assetType_, assetType);
    }

    function testFuzz_Success_processAsset(uint256 assetType, address asset, uint96 assetId) public {
        AssetModuleMock assetModule_ = new AssetModuleMock(address(registryExtension), assetType);

        assetModule_.setIsAllowedResponse(true);

        (bool isAllowed, uint256 assetType_) = assetModule_.processAsset(asset, assetId);
        assertTrue(isAllowed);
        assertEq(assetType_, assetType);
    }
}
