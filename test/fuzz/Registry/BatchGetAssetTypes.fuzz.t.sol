/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";
import { AssetModule } from "../../../src/asset-modules/abstracts/AbstractAM.sol";

/**
 * @notice Fuzz tests for the function "batchGetAssetTypes" of contract "Registry".
 */
contract BatchGetAssetTypes_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_batchGetAssetTypes_UnknownAsset(address asset) public {
        vm.assume(!registryExtension.inRegistry(asset));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = asset;

        vm.expectRevert(RegistryErrors.UnknownAsset.selector);
        registryExtension.batchGetAssetTypes(assetAddresses);
    }

    function testFuzz_Success_batchGetAssetTypes(uint96 assetType, address asset, address assetModule) public {
        vm.assume(assetType > 0);
        vm.assume(!registryExtension.inRegistry(asset));

        registryExtension.setAssetInformation(asset, assetType, assetModule);

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = asset;

        uint256[] memory assetTypes = registryExtension.batchGetAssetTypes(assetAddresses);
        assertEq(assetTypes[0], 1);
        assertEq(assetTypes[1], assetType);
    }
}
