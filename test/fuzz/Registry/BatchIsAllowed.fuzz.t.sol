/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "batchIsAllowed" of contract "Registry".
 */
contract BatchIsAllowed_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_revert_batchIsAllowed_LengthMismatch() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.stable2);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        vm.expectRevert(RegistryErrors.Length_Mismatch.selector);
        registryExtension.batchIsAllowed(assetAddresses, assetIds);
    }

    function testFuzz_Success_batchIsAllowed_Negative_UnknownAsset(address randomAsset, uint256 assetId) public {
        vm.assume(randomAsset != address(mockERC20.stable1));
        vm.assume(randomAsset != address(mockERC20.stable2));
        vm.assume(randomAsset != address(mockERC20.token1));
        vm.assume(randomAsset != address(mockERC20.token2));
        vm.assume(randomAsset != address(mockERC721.nft1));
        vm.assume(randomAsset != address(mockERC1155.sft1));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = randomAsset;

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = assetId;

        assertFalse(registryExtension.batchIsAllowed(assetAddresses, assetIds));
    }

    function testFuzz_Success_batchIsAllowed_Negative_NonAllowedAsset() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC1155.sft1);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 2;

        assertFalse(registryExtension.batchIsAllowed(assetAddresses, assetIds));
    }

    function testFuzz_Success_batchIsAllowed_Positive() public {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(mockERC20.token1);
        assetAddresses[1] = address(mockERC20.stable2);

        uint256[] memory assetIds = new uint256[](2);
        assetIds[0] = 0;
        assetIds[1] = 0;

        assertTrue(registryExtension.batchIsAllowed(assetAddresses, assetIds));
    }
}
