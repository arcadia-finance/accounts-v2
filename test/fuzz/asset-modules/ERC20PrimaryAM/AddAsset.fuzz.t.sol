/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20PrimaryAM_Fuzz_Test } from "./_ERC20PrimaryAM.fuzz.t.sol";

import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

import { Constants } from "../../../utils/Constants.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { PrimaryAM, ERC20PrimaryAM } from "../../../../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "ERC20PrimaryAM".
 */
contract AddAsset_ERC20PrimaryAM_Fuzz_Test is ERC20PrimaryAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ERC20PrimaryAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.owner);

        vm.prank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        erc20AM.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);
    }

    function testFuzz_Revert_addAsset_BadOracleSequence() public {
        bool[] memory badDirection = new bool[](1);
        badDirection[0] = false;
        uint80[] memory oracleToken4ToUsdArr = new uint80[](1);
        oracleToken4ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token4ToUsd)));
        bytes32 badSequence = BitPackingLib.pack(badDirection, oracleToken4ToUsdArr);

        vm.startPrank(users.owner);
        vm.expectRevert(PrimaryAM.BadOracleSequence.selector);
        erc20AM.addAsset(address(mockERC20.token4), badSequence);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(users.owner);
        erc20AM.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        erc20AM.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_MoreThan18Decimals() public {
        ArcadiaOracle oracle = initMockedOracle(uint8(0), "ASSET / USD", int256(0));
        vm.prank(users.tokenCreator);
        ERC20Mock asset = new ERC20Mock("ASSET", "ASSET", 19);
        vm.prank(users.owner);
        chainlinkOM.addOracle(address(oracle), "ASSET", "USD", 2 days);
        vm.stopPrank();

        uint80[] memory oracleAssetToUsdArr = new uint80[](1);
        oracleAssetToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(oracle)));

        vm.prank(users.owner);
        vm.expectRevert(ERC20PrimaryAM.Max18Decimals.selector);
        erc20AM.addAsset(address(asset), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAssetToUsdArr));
    }

    function testFuzz_Success_addAsset() public {
        vm.prank(users.owner);
        erc20AM.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);

        assertTrue(erc20AM.inAssetModule(address(mockERC20.token4)));
        assertTrue(erc20AM.isAllowed(address(mockERC20.token4), 0));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token4)));
        (uint64 assetUnit, bytes32 oracles) = erc20AM.assetToInformation(assetKey);
        assertEq(assetUnit, 10 ** Constants.TOKEN_DECIMALS);
        assertEq(oracles, oraclesToken4ToUsd);

        assertTrue(registry.inRegistry(address(mockERC20.token4)));
        (uint256 assetType, address assetModule) = registry.assetToAssetInformation(address(mockERC20.token4));
        assertEq(assetType, 1);
        assertEq(assetModule, address(erc20AM));
    }
}
